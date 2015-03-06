# The scripts for starting services are in different places depending on the hdp version, so set them here
{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set hbase_script_dir = '/usr/hdp/current/hbase-master/bin' %}
{% else %}
{% set hbase_script_dir = '/usr/lib/hbase/bin' %}
{% endif %}

#
# Start the HBase master service
#
include:
  - hdp2.repo
  - hdp2.hadoop.client
  - hdp2.zookeeper
  - hdp2.hbase.conf


# When security is enabled, we need to get a kerberos ticket
# for the hdfs principal so that any interaction with HDFS
# through the hadoop client may authorize successfully.
# NOTE this means that any 'hdfs dfs' commands will need
# to require this state to be sure we have a krb ticket
{% if salt['pillar.get']('hdp2:security:enable', False) %}
hdfs_kinit:
  cmd:
    - run
    - name: 'kinit -kt /etc/hadoop/conf/hdfs.keytab hdfs/{{ grains.fqdn }}'
    - user: hdfs
    - group: hdfs
    - require:
      - cmd: generate_hbase_keytabs
{% endif %}

hbase-init:
  cmd:
    - run
    - user: hdfs
    - group: hdfs
    - name: 'hdfs dfs -mkdir /hbase && hdfs dfs -chown hbase:hbase /hbase'
    - unless: 'hdfs dfs -test -d /hbase'
    - require:
      - pkg: hadoop-client
{% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: hdfs_kinit
{% endif %}

hbase-master-svc:
  cmd:
    - run
    - user: hbase
    - name: {{ hbase_script_dir }}/hbase-daemon.sh start master && sleep 25
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hbase/hbase-hbase-master.pid'
    - require: 
      - pkg: hbase-master
      - cmd: hbase-init
      - cmd: zookeeper-server-svc
      - file: /etc/hbase/conf/hbase-site.xml
      - file: /etc/hbase/conf/hbase-env.sh
      - file: {{ pillar.hdp2.hbase.tmp_dir }}
      - file: {{ pillar.hdp2.hbase.log_dir }}
{% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hbase_keytabs
{% endif %}
    - watch:
      - file: /etc/hbase/conf/hbase-site.xml
      - file: /etc/hbase/conf/hbase-env.sh

hbase-thrift-svc:
  cmd:
    - run
    - user: hbase
    - name: {{ hbase_script_dir }}/hbase-daemon.sh start thrift
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hbase/hbase-hbase-thrift.pid'
    - require:
      - cmd: hbase-master-svc

