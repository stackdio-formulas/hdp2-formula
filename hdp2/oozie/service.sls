{% set nn_host = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:hdp2.hadoop.hdfs.namenode', 'grains.items', 'compound').values()[0]['fqdn'] %}
{% set oozie_data_dir = '/var/lib/oozie' %}

# The scripts for starting services are in different places depending on the hdp version, so set them here
{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set oozie_home = '/usr/hdp/current/oozie-server' %}

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
{% endif %}

kill-oozie:
  cmd:
    - run
    - user: oozie
    - name: {{ oozie_home }}/bin/oozied.sh stop
    - onlyif: '. /etc/init.d/functions && pidofproc -p /var/run/oozie/oozie.pid'
    - require:
      - pkg: oozie

# 
# Start the Oozie service
#

prepare_server:
  cmd:
    - run
    - name: '{{ oozie_home }}/bin/oozie-setup.sh prepare-war{% if pillar.hdp2.encryption.enable %} -secure{% endif %}'
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/oozie/oozie.pid'
    - user: root
    - require:
      - pkg: oozie
      - cmd: extjs
      - file: /etc/oozie/conf/oozie-env.sh
      - file: /var/lib/oozie
      - file: /var/log/oozie
      - cmd: kill-oozie
      {% if pillar.hdp2.security.enable %}
      - file: /etc/oozie/conf/oozie-site.xml
      - cmd: generate_oozie_keytabs
      {% endif %}

{% if pillar.hdp2.security.enable %}
hdfs_kinit:
  cmd:
    - run
    - name: 'kinit -kt /etc/hadoop/conf/hdfs.keytab hdfs/{{ grains.fqdn }}'
    - user: hdfs
    - env:
      - KRB5_CONFIG: '{{ pillar.krb5.conf_file }}'
    - require_in:
      - cmd: create-oozie-sharelibs
      - cmd: wait-for-safemode

oozie_kinit:
  cmd:
    - run
    - name: 'kinit -kt /etc/oozie/conf/oozie.keytab oozie/{{ grains.fqdn }}'
    - user: oozie
    - env:
      - KRB5_CONFIG: '{{ pillar.krb5.conf_file }}'
    - require:
      - pkg: oozie
      - cmd: generate_oozie_keytabs
    - require_in:
      - cmd: populate-oozie-sharelibs

oozie_kdestroy:
  cmd:
    - run
    - name: kdestroy
    - user: oozie
    - env:
      - KRB5_CONFIG: '{{ pillar.krb5.conf_file }}'
    - require:
      - pkg: oozie
      - cmd: oozie_kinit
    - require_in:
      - cmd: oozie-svc
{% endif %}

wait-for-safemode:
  cmd:
    - run
    - name: 'hdfs dfsadmin -safemode wait'
    - user: hdfs
    - require:
      - cmd: kill-oozie

create-oozie-sharelibs:
  cmd:
    - run
    - name: 'hdfs dfs -mkdir -p /user/oozie && hdfs dfs -chown -R oozie:oozie /user/oozie'
    - user: hdfs
    - require:
      - cmd: prepare_server
      - cmd: wait-for-safemode

{% if pillar.hdp2.security.enable %}
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
    {% if pillar.hdp2.security.enable %}
    - name: '{{ oozie_home }}/bin/oozie-sharelib-kerberos.sh create -fs hdfs://{{nn_host}}:8020 -locallib {{ oozie_home }}/oozie-sharelib.tar.gz'
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
    {% if pillar.hdp2.security.enable %}
    - env:
      - JAVA_PROPERTIES: '-Djava.security.krb5.conf={{ pillar.krb5.conf_file }}'
    {% endif %}
    - require:
      - pkg: oozie
      - cmd: extjs
      - cmd: kill-oozie
      - cmd: prepare_server
      - cmd: populate-oozie-sharelibs
      - file: /var/log/oozie
      {% if pillar.hdp2.encryption.enable %}
      - cmd: chown-keystore
      - cmd: create-truststore
      {% endif %}
