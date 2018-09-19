# The scripts for starting services are in different places depending on the hdp version, so set them here
{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set hbase_script_dir = '/usr/hdp/current/hbase-master/bin' %}
{% else %}
{% set hbase_script_dir = '/usr/lib/hbase/bin' %}
{% endif %}

{% set kms = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:hdp2.hadoop.kms', 'grains.items', 'compound') %}

#
# Start the HBase master service
#

kill-master:
  cmd:
    - run
    - user: hbase
    - name: {{ hbase_script_dir }}/hbase-daemon.sh stop master
    - onlyif: '. /etc/init.d/functions && pidofproc -p /var/run/hbase/hbase-hbase-master.pid'
    - require:
      - pkg: hbase-master

kill-thrift:
  cmd:
    - run
    - user: hbase
    - name: {{ hbase_script_dir }}/hbase-daemon.sh stop thrift
    - onlyif: '. /etc/init.d/functions && pidofproc -p /var/run/hbase/hbase-hbase-thrift.pid'
    - require:
      - cmd: kill-master

# When security is enabled, we need to get a kerberos ticket
# for the hdfs principal so that any interaction with HDFS
# through the hadoop client may authorize successfully.
# NOTE this means that any 'hdfs dfs' commands will need
# to require this state to be sure we have a krb ticket
{% if pillar.hdp2.security.enable %}
hdfs-kinit:
  cmd:
    - run
    - name: 'kinit -kt /etc/hadoop/conf/hdfs.keytab hdfs/{{ grains.fqdn }}'
    - user: hdfs
    - group: hdfs
    - env:
      - KRB5_CONFIG: '{{ pillar.krb5.conf_file }}'
    - require:
      - cmd: hbase-kinit

hdfs-kdestroy:
  cmd:
    - run
    - name: 'kdestroy'
    - user: hdfs
    - group: hdfs
    - env:
      - KRB5_CONFIG: '{{ pillar.krb5.conf_file }}'
    - require:
      - cmd: hdfs-kinit
      - cmd: hbase-init
    - require_in:
      - service: hbase-master-svc

hbase-kinit:
  cmd:
    - run
    - name: 'kinit -kt /etc/hbase/conf/hbase.keytab hbase/{{ grains.fqdn }}'
    - user: hbase
    - env:
      - KRB5_CONFIG: '{{ pillar.krb5.conf_file }}'
    - require:
      - cmd: generate_hbase_keytabs

hbase-kdestroy:
  cmd:
    - run
    - name: 'kdestroy'
    - user: hbase
    - env:
      - KRB5_CONFIG: '{{ pillar.krb5.conf_file }}'
    - require:
      - cmd: hbase-kinit
    - require_in:
      - service: hbase-master-svc
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
      - pkg: hbase-master

{% if kms %}
create_hbase_key:
  cmd:
    - run
    - user: hbase
    - name: 'hadoop key create hbase'
    - unless: 'hadoop key list | grep hbase'
    {% if pillar.hdp2.security.enable %}
    - require:
      - cmd: hbase-kinit
    - require_in:
      - cmd: hbase-kdestroy
    {% endif %}

create_hbase_zone:
  cmd:
    - run
    - user: hdfs
    - name: 'hdfs crypto -createZone -keyName hbase -path /hbase'
    - unless: 'hdfs crypto -listZones | grep /hbase'
    - require:
      - cmd: create_hbase_key
      - cmd: hbase-init
    - require_in:
      - cmd: hbase-master-svc
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
      - cmd: kill-master
      - file: {{ pillar.hdp2.hbase.tmp_dir }}
      - file: {{ pillar.hdp2.hbase.log_dir }}
      {% if pillar.hdp2.encryption.enable %}
      - cmd: chown-keystore
      - cmd: create-truststore
      - cmd: chown-hbase-keystore
      - cmd: create-hbase-truststore
      {% endif %}
      {% if pillar.hdp2.security.enable %}
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
      - cmd: kill-thrift
      {% if pillar.hdp2.encryption.enable %}
      - cmd: chown-keystore
      - cmd: create-truststore
      - cmd: chown-hbase-keystore
      - cmd: create-hbase-truststore
      {% endif %}
    - watch:
      - file: /etc/hbase/conf/hbase-site.xml
      - file: /etc/hbase/conf/hbase-env.sh
