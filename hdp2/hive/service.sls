
# The scripts for starting services are in different places depending on the hdp version, so set them here
{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set hive_home = '/usr/hdp/current/hive-metastore' %}
{% else %}
{% set hive_home = '/usr/lib/hive' %}
{% endif %}

{% set kms = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:hdp2.hadoop.kms', 'grains.items', 'compound') %}

# 
# Start the Hive service
#

include:
  - hdp2.repo


kill-metastore:
  cmd:
    - run
    - user: hive
    - name: '{{ hive_home }}/bin/hive-daemon.sh stop hive-metastore'
    - onlyif: '. /etc/init.d/functions && pidofproc -p /var/run/hive/hive-metastore.pid'
    - require:
      - pkg: hive

kill-server2:
  cmd:
    - run
    - user: hive
    - name: '{{ hive_home }}/bin/hive-daemon.sh stop hive-server2'
    - onlyif: '. /etc/init.d/functions && pidofproc -p /var/run/hive/hive-server2.pid'
    - require:
      - pkg: hive


# @todo move this out to its own formula
mysql-svc:
  service:
    - running
    {% if grains['os_family'] == 'Debian' %}
    - name: mysql
    {% elif grains['os_family'] == 'RedHat' %}
    - name: mysqld
    {% endif %}
    - require:
      - pkg: mysql

{% if salt['pillar.get']('hdp2:security:enable', False) %}
hdfs_kinit:
  cmd:
    - run
    - name: 'kinit -kt /etc/hadoop/conf/hdfs.keytab hdfs/{{ grains.fqdn }}'
    - user: hdfs
    - env:
      - KRB5_CONFIG: '{{ pillar.krb5.conf_file }}'

hive_kinit:
  cmd:
    - run
    - name: 'kinit -kt /etc/hive/conf/hive.keytab hive/{{ grains.fqdn }}'
    - user: hive
    - env:
      - KRB5_CONFIG: '{{ pillar.krb5.conf_file }}'
    - require:
      - cmd: generate_hive_keytabs
{% endif %}

create_anonymous_user:
  cmd:
    - run
    - name: 'hdfs dfs -mkdir -p /user/anonymous && hdfs dfs -chown anonymous:anonymous /user/anonymous'
    - user: hdfs
    {% if salt['pillar.get']('hdp2:security:enable', False) %}
    - require:
      - cmd: hdfs_kinit
    {% endif %}

configure_metastore:
  cmd:
    - script
    - template: jinja
    - source: salt://hdp2/hive/configure_metastore.sh
    - unless: echo "show databases" | mysql -u root | grep metastore
    - require:
      - pkg: hive
      - service: mysql-svc
      - file: {{ hive_home }}/lib/mysql-connector-java.jar

create_hive_dir:
  cmd:
    - run
    - user: hdfs
    - name: 'hdfs dfs -mkdir -p /user/{{ pillar.hdp2.hive.user }} && hdfs dfs -chown -R {{pillar.hdp2.hive.user}}:{{pillar.hdp2.hive.user}} /user/{{pillar.hdp2.hive.user}}'
    {% if salt['pillar.get']('hdp2:security:enable', False) %}
    - require:
      - cmd: hdfs_kinit
    {% endif %}

{% if kms %}
create_hive_key:
  cmd:
    - run
    - user: hive
    - name: 'hadoop key create hive'
    - unless: 'hadoop key list | grep hive'
    {% if salt['pillar.get']('hdp2:security:enable', False) %}
    - require:
      - cmd: hive_kinit
    {% endif %}

create_hive_zone:
  cmd:
    - run
    - user: hdfs
    - name: 'hdfs crypto -createZone -keyName hive -path /user/{{ pillar.hdp2.hive.user }}'
    - unless: 'hdfs crypto -listZones | grep /user/{{ pillar.hdp2.hive.user }}'
    - require:
      - cmd: create_hive_key
      - cmd: create_hive_dir
    - require_in:
      - cmd: hive-metastore
      - cmd: create_warehouse_dir
      - cmd: create_scratch_dir
{% endif %}

create_warehouse_dir:
  cmd:
    - run
    - name: 'hdfs dfs -mkdir -p /user/{{pillar.hdp2.hive.user}}/warehouse'
    - user: hive
    - require:
      - pkg: hive
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: hive_kinit
      {% endif %}

create_scratch_dir:
  cmd:
    - run
    - name: 'hdfs dfs -mkdir -p /user/{{pillar.hdp2.hive.user}}/tmp'
    - user: hive
    - require:
      - pkg: hive
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: hive_kinit
      {% endif %}

# This was chmodding the dir to 771 permissions, and it was breaking things
warehouse_dir_permissions:
  cmd:
    - run
    - name: 'hdfs dfs -chmod 1777 /user/{{pillar.hdp2.hive.user}}/warehouse'
    - user: hive
    - require:
      - cmd: create_warehouse_dir

scratch_dir_permissions:
  cmd:
    - run
    - name: 'hdfs dfs -chmod 1777 /user/{{pillar.hdp2.hive.user}}/tmp'
    - user: hive
    - require:
      - cmd: create_scratch_dir

{{ hive_home }}/bin/hive-daemon.sh:
  file:
    - managed
    - template: jinja
    - source: salt://hdp2/hive/hive-daemon.sh
    - user: root
    - group: root
    - mode: 755
    - require:
      - pkg: hive

/etc/profile.d/hive.sh:
  file:
    - managed
    - user: root
    - group: root
    - mode: 644
    - contents: 'export HIVE_HOME={{ hive_home }} ; export HIVE_BIN=$HIVE_HOME/bin ; export HIVE_CONF_DIR=$HIVE_HOME/conf'

hive-metastore:
  cmd:
    - run
    - user: hive
    - name: '{{ hive_home }}/bin/hive-daemon.sh start hive-metastore'
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hive/hive-metastore.pid'
    - require:
      - file: {{ hive_home }}/bin/hive-daemon.sh
      - pkg: hive
      - cmd: configure_metastore
      - cmd: warehouse_dir_permissions
      - cmd: scratch_dir_permissions
      - cmd: kill-metastore
      - service: mysql-svc
      - file: {{ hive_home }}/lib/mysql-connector-java.jar
      - file: /etc/hive/conf/hive-site.xml
      - file: /mnt/tmp/
    - watch:
      - file: /etc/hive/conf/hive-site.xml

hive-server2:
  cmd:
    - run
    - user: hive
    - name: '{{ hive_home }}/bin/hive-daemon.sh start hive-server2'
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hive/hive-server2.pid'
    - require: 
      - cmd: hive-metastore
      - cmd: kill-server2
{% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hive_keytabs 
{% endif %}
    - watch:
      - file: /etc/hive/conf/hive-site.xml

/mnt/tmp/:
  file:
    - directory
    - user: root
    - group: root
    - dir_mode: 777
    - recurse:
      - mode
