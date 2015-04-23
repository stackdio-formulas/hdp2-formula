{% set nn_host = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:hdp2.hadoop.namenode and not G@roles:hdp2.hadoop.standby', 'grains.items', 'compound').values()[0]['fqdn'] %}

# The scripts for starting services are in different places depending on the hdp version, so set them here
{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set oozie_home = '/usr/hdp/current/oozie-server' %}
{% set oozie_data_dir = '/var/lib/oozie/data' %}

copy_ssl_conf:
  cmd:
    - run
    - user: root
    - name: cp -r {{ oozie_home }}/tomcat-deployment/conf/ssl /etc/oozie/conf
    - unless: 'test -d /etc/oozie/conf/ssl'
    - require:
      - pkg: oozie
    - require_in:
      - cmd: prepare_server

fix_symlink:
  cmd:
    - run
    - user: root
    - name: 'ln -s `find /usr/hdp -name {{ pillar.hdp2.version }}-*`/oozie `find /usr/hdp -name {{ pillar.hdp2.version }}-*`/oozie-server'
    - unless: 'test -d `find /usr/hdp -name {{ pillar.hdp2.version }}-*`/oozie-server'
    - require:
      - pkg: oozie
    - require_in:
      - cmd: prepare_server

{% else %}
{% set oozie_home = '/usr/lib/oozie' %}
{% set oozie_data_dir = '/var/lib/oozie' %}
{% endif %}

# 
# Start the Oozie service
#

prepare_server:
  cmd:
    - run
    - name: '{{ oozie_home }}/bin/oozie-setup.sh prepare-war'
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/oozie/oozie.pid'
    - user: root
    - require:
      - pkg: oozie
      - cmd: extjs
      - file: /etc/oozie/conf/oozie-env.sh
{% if salt['pillar.get']('hdp2:security:enable', False) %}
      - file: /etc/oozie/conf/oozie-site.xml
      - cmd: generate_oozie_keytabs
{% endif %}

ooziedb:
  cmd:
    - run
    - name: '{{ oozie_home }}/bin/ooziedb.sh create -sqlfile /var/lib/oozie/data/oozie-db-creation.sql -run Validate DB Connection'
    - unless: 'test -d {{ oozie_data_dir }}/oozie-db'
    - user: oozie
    - env:
      - KRB5_CONFIG: '{{ pillar.krb5.conf_file }}'
    - require:
      - cmd: prepare_server

create-oozie-sharelibs:
  cmd:
    - run
    - name: 'hdfs dfs -mkdir /user/oozie && hdfs dfs -chown -R oozie:oozie /user/oozie'
    - unless: 'hdfs dfs -test -d /user/oozie'
    - user: hdfs
    - require:
      - cmd: ooziedb

{% if salt['pillar.get']('hdp2:security:enable', False) %}
create_sharelib_script:
  file:
    - managed
    - name: {{ oozie_home }}/bin/oozie-sharelib-kerberos.sh
    - source: salt://hdp2/oozie/create_sharelibs.sh
    - user: root
    - group: root
    - mode: 755
    - template: jinja
    - require_in:
      - cmd: populate-oozie-sharelibs
{% endif %}

populate-oozie-sharelibs:
  cmd:
    - run
    {% if salt['pillar.get']('hdp2:security:enable', False) %}
    - name: '{{ oozie_home }}/bin/oozie-sharelib-kerberos.sh create -fs hdfs://{{nn_host}}:8020 -locallib {{ oozie_home }}/oozie-sharelib-yarn.tar.gz'
    {% else %}
    - name: '{{ oozie_home }}/bin/oozie-setup.sh sharelib create -fs hdfs://{{nn_host}}:8020 -locallib {{ oozie_home }}/oozie-sharelib.tar.gz'
    {% endif %}
    - user: oozie
    - unless: 'hdfs dfs -test -d /user/oozie/share'
    - require:
      - cmd: create-oozie-sharelibs

oozie-svc:
  cmd:
    - run
    - user: oozie
    - name: {{ oozie_home }}/bin/oozied.sh start
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/oozie/oozie.pid'
    - require:
      - pkg: oozie
      - cmd: extjs
      - cmd: ooziedb
      - cmd: populate-oozie-sharelibs
      - file: /var/log/oozie
