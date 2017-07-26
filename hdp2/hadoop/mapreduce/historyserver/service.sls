{% set kms = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:hdp2.hadoop.kms', 'grains.items', 'compound') %}
{% set mapred_staging_dir = '/user/history' %}
{% set mapred_log_dir = '/var/log/hadoop-yarn' %}

# The scripts for starting services are in different places depending on the hdp version, so set them here
{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set hadoop_script_dir = '/usr/hdp/current/hadoop-mapreduce-historyserver/../hadoop/sbin' %}
{% set mapred_script_dir = '/usr/hdp/current/hadoop-mapreduce-historyserver/sbin' %}
{% else %}
{% set hadoop_script_dir = '/usr/lib/hadoop/sbin' %}
{% set mapred_script_dir = '/usr/lib/hadoop-mapreduce/sbin' %}
{% endif %}

kill-historyserver:
  cmd:
    - run
    - user: mapred
    - name: {{ mapred_script_dir }}/mr-jobhistory-daemon.sh stop historyserver
    - onlyif: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop-mapreduce/mapred-mapred-historyserver.pid'
    - env:
      - HADOOP_MAPRED_HOME: '{{ mapred_script_dir }}/..'
      - HADOOP_MAPRED_LOG_DIR: '/var/log/hadoop-mapreduce'
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - require:
      - pkg: hadoop-mapreduce-historyserver


# When security is enabled, we need to get a kerberos ticket
# for the hdfs principal so that any interaction with HDFS
# through the hadoop client may authorize successfully.
# NOTE this means that any 'hdfs dfs' commands will need
# to require this state to be sure we have a krb ticket
{% if pillar.hdp2.security.enable %}
hdfs_kinit_for_mapred:
  cmd:
    - run
    - name: 'kinit -kt /etc/hadoop/conf/hdfs.keytab hdfs/{{ grains.fqdn }}'
    - user: hdfs
    - group: hdfs
    - env:
      - KRB5_CONFIG: '{{ pillar.krb5.conf_file }}'
    - require:
      - cmd: generate_hadoop_keytabs
    - require_in:
      - cmd: hdfs_mapreduce_log_dir
      - cmd: hdfs_mapreduce_var_dir
      - cmd: hdfs_mr_framework_dir

hdfs_kdestroy_for_mapred:
  cmd:
    - run
    - name: 'kdestroy'
    - user: hdfs
    - group: hdfs
    - env:
      - KRB5_CONFIG: '{{ pillar.krb5.conf_file }}'
    - require:
      - cmd: hdfs_kinit_for_mapred
      - cmd: hdfs_mapreduce_log_dir
      - cmd: hdfs_mapreduce_var_dir
      - cmd: hdfs_mr_framework_upload
{% endif %}

hdfs_mr_framework_dir:
  cmd:
    - run
    - user: hdfs
    - name: 'hdfs dfs -mkdir -p /hdp/apps/mapreduce'

hdfs_mr_framework_upload:
  cmd:
    - run
    - user: hdfs
    - name: 'hdfs dfs -put -f /usr/hdp/current/hadoop-client/mapreduce.tar.gz /hdp/apps/mapreduce'
    - require:
      - cmd: hdfs_mr_framework_dir

# HDFS MapReduce log directories
hdfs_mapreduce_log_dir:
  cmd:
    - run
    - user: hdfs
    - group: hdfs
    - name: 'hdfs dfs -mkdir -p {{ mapred_log_dir }} && hdfs dfs -chown yarn:hadoop {{ mapred_log_dir }}'

# HDFS MapReduce var directories
hdfs_mapreduce_var_dir:
  cmd:
    - run
    - user: hdfs
    - group: hdfs
    - name: 'hdfs dfs -mkdir -p {{ mapred_staging_dir }} && hdfs dfs -chmod -R 1777 {{ mapred_staging_dir }} && hdfs dfs -chown mapred:hadoop {{ mapred_staging_dir }}'

{% if kms %}

{% if pillar.hdp2.security.enable %}
mapred_kinit:
  cmd:
    - run
    - name: 'kinit -kt /etc/hadoop/conf/mapred.keytab mapred/{{ grains.fqdn }}'
    - user: mapred
    - env:
      - KRB5_CONFIG: '{{ pillar.krb5.conf_file }}'
    - require:
      - cmd: generate_hadoop_keytabs
    - require_in:
      - cmd: create_mapred_key
      - cmd: create_mapred_zone

mapred_kdestroy:
  cmd:
    - run
    - name: 'kdestroy'
    - user: mapred
    - env:
      - KRB5_CONFIG: '{{ pillar.krb5.conf_file }}'
    - require:
      - cmd: mapred_kinit
      - cmd: create_mapred_key
      - cmd: create_mapred_zone
{% endif %}


create_mapred_key:
  cmd:
    - run
    - user: mapred
    - name: 'hadoop key create mapred'
    - unless: 'hadoop key list | grep mapred'
    - require:
      - file: /etc/hadoop/conf
      {% if pillar.hdp2.security.enable %}
      - cmd: mapred_kinit
      {% endif %}

create_mapred_zone:
  cmd:
    - run
    - user: hdfs
    - name: 'hdfs crypto -createZone -keyName mapred -path {{ mapred_staging_dir }}'
    - unless: 'hdfs crypto -listZones | grep {{ mapred_staging_dir }}'
    - require:
      - cmd: create_mapred_key
      - cmd: hdfs_mapreduce_var_dir
    - require_in:
      - cmd: hadoop-mapreduce-historyserver-svc
{% endif %}

##
# Installs the mapreduce historyserver service and starts it.
#
# Depends on: JDK7
##
hadoop-mapreduce-historyserver-svc:
  cmd:
    - run
    - user: mapred
    - name: {{ mapred_script_dir }}/mr-jobhistory-daemon.sh start historyserver
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop-mapreduce/mapred-mapred-historyserver.pid'
    - env:
      - HADOOP_MAPRED_HOME: '{{ mapred_script_dir }}/..'
      - HADOOP_MAPRED_LOG_DIR: '/var/log/hadoop-mapreduce'
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - require:
      - pkg: hadoop-mapreduce-historyserver
      - cmd: hdfs_mapreduce_var_dir
      - cmd: hdfs_mapreduce_log_dir
      - file: bigtop_java_home
      - cmd: kill-historyserver
      {% if pillar.hdp2.security.enable %}
      - cmd: generate_hadoop_keytabs
      {% endif %}
    - watch:
      - file: /etc/hadoop/conf
