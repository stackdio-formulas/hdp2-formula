{% set standby = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:hdp2.hadoop.standby-namenode', 'grains.items', 'compound') %}
{% set kms = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:hdp2.hadoop.kms', 'grains.items', 'compound') %}
{% set dfs_name_dir = salt['pillar.get']('hdp2:dfs:name_dir', '/mnt/hadoop/hdfs/nn') %}
{% set mapred_local_dir = salt['pillar.get']('hdp2:mapred:local_dir', '/mnt/hadoop/mapred/local') %}
{% set mapred_system_dir = salt['pillar.get']('hdp2:mapred:system_dir', '/hadoop/system/mapred') %}
{% set mapred_staging_dir = '/user/history' %}
{% set mapred_log_dir = '/var/log/hadoop-yarn' %}

# The scripts for starting services are in different places depending on the hdp version, so set them here
{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set hadoop_script_dir = '/usr/hdp/current/hadoop-hdfs-namenode/../hadoop/sbin' %}
{% set yarn_script_dir = '/usr/hdp/current/hadoop-yarn-resourcemanager/sbin' %}
{% set mapred_script_dir = '/usr/hdp/current/hadoop-mapreduce-historyserver/sbin' %}
{% else %}
{% set hadoop_script_dir = '/usr/lib/hadoop/sbin' %}
{% set yarn_script_dir = '/usr/lib/hadoop-yarn/sbin' %}
{% set mapred_script_dir = '/usr/lib/hadoop-mapreduce/sbin' %}
{% endif %}

##
# Starts the namenode service.
#
# Depends on: JDK7
##

{% if standby %}
kill-zkfc:
  cmd:
    - run
    - user: hdfs
    - name: {{ hadoop_script_dir }}/hadoop-daemon.sh stop zkfc
    - onlyif: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/hdfs/hadoop-hdfs-zkfc.pid'
    - env:
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - require:
      - pkg: hadoop-hdfs-zkfc
{% endif %}

kill-namenode:
  cmd:
    - run
    - user: hdfs
    - name: {{ hadoop_script_dir }}/hadoop-daemon.sh stop namenode
    - onlyif: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/hdfs/hadoop-hdfs-namenode.pid'
    - env:
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - require:
      - pkg: hadoop-hdfs-namenode

kill-resourcemanager:
  cmd:
    - run
    - user: yarn
    - name: {{ yarn_script_dir }}/yarn-daemon.sh stop resourcemanager
    - onlyif: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/yarn/yarn-yarn-resourcemanager.pid'
    - env:
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - require:
      - pkg: hadoop-yarn-resourcemanager

kill-historyserver:
  cmd:
    - run
    - user: mapred
    - name: {{ mapred_script_dir }}/mr-jobhistory-daemon.sh stop historyserver
    - onlyif: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/mapreduce/mapred-mapred-historyserver.pid'
    - env:
      - HADOOP_MAPRED_HOME: '{{ mapred_script_dir }}/..'
      - HADOOP_MAPRED_LOG_DIR: '/var/log/hadoop/mapreduce'
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - require:
      - pkg: hadoop-mapreduce-historyserver

##
# Make sure the namenode metadata directory exists
# and is owned by the hdfs user
##
hdp2_dfs_dirs:
  cmd:
    - run
    - name: 'mkdir -p {{ dfs_name_dir }} && chown -R hdfs:hdfs `dirname {{ dfs_name_dir }}`'
    - unless: 'test -d {{ dfs_name_dir }}'
    - require:
      - pkg: hadoop-hdfs-namenode
      - file: bigtop_java_home
{% if pillar.hdp2.security.enable %}
      - cmd: generate_hadoop_keytabs
{% endif %}

# Initialize HDFS. This should only run once, immediately
# following an install of hadoop.
init_hdfs:
  cmd:
    - run
    - user: hdfs
    - group: hdfs
    - name: 'hdfs namenode -format -force'
    - unless: 'test -d {{ dfs_name_dir }}/current'
    - require:
      - cmd: hdp2_dfs_dirs

{% if standby %}
init_zkfc:
  cmd:
    - run
    - name: hdfs zkfc -formatZK
    - user: hdfs
    - group: hdfs
    - unless: 'zookeeper-client stat /hadoop-ha 2>&1 | grep "cZxid"'
    - require:
      - cmd: hdp2_dfs_dirs

# Start up the ZKFC
hadoop-hdfs-zkfc-svc:
  cmd:
    - run
    - user: hdfs
    - name: {{ hadoop_script_dir }}/hadoop-daemon.sh start zkfc
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/hdfs/hadoop-hdfs-zkfc.pid'
    - env:
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - require:
      - pkg: hadoop-hdfs-zkfc
      - cmd: init_zkfc
      - file: bigtop_java_home
      - cmd: kill-zkfc
    - require_in:
      - cmd: hadoop-yarn-resourcemanager-svc
      - cmd: hadoop-mapreduce-historyserver-svc
    - watch:
      - file: /etc/hadoop/conf
{% endif %}

hadoop-hdfs-namenode-svc:
  cmd:
    - run
    - user: hdfs
    - name: {{ hadoop_script_dir }}/hadoop-daemon.sh start namenode
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/hdfs/hadoop-hdfs-namenode.pid'
    - env:
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - require: 
      - pkg: hadoop-hdfs-namenode
      # Make sure HDFS is initialized before the namenode
      # is started
      - cmd: init_hdfs
      - file: bigtop_java_home
      - cmd: kill-namenode
      {% if pillar.hdp2.encryption.enable %}
      - cmd: chown-keystore
      {% endif %}
    - watch:
      - file: /etc/hadoop/conf

# When security is enabled, we need to get a kerberos ticket
# for the hdfs principal so that any interaction with HDFS
# through the hadoop client may authorize successfully.
# NOTE this means that any 'hdfs dfs' commands will need
# to require this state to be sure we have a krb ticket
{% if pillar.hdp2.security.enable %}
hdfs_kinit:
  cmd:
    - run
    - name: 'kinit -kt /etc/hadoop/conf/hdfs.keytab hdfs/{{ grains.fqdn }}'
    - user: hdfs
    - group: hdfs
    - env:
      - KRB5_CONFIG: '{{ pillar.krb5.conf_file }}'
    - require:
      - cmd: hadoop-hdfs-namenode-svc
      - cmd: generate_hadoop_keytabs
    - require_in:
      - cmd: hdfs_tmp_dir
      - cmd: hdfs_mapreduce_log_dir
      - cmd: hdfs_mapreduce_var_dir

mapred_kinit:
  cmd:
    - run
    - name: 'kinit -kt /etc/hadoop/conf/mapred.keytab mapred/{{ grains.fqdn }}'
    - user: mapred
    - env:
      - KRB5_CONFIG: '{{ pillar.krb5.conf_file }}'
    - require:
      - cmd: hadoop-hdfs-namenode-svc
      - cmd: generate_hadoop_keytabs
{% endif %}

# HDFS tmp directory
hdfs_tmp_dir:
  cmd:
    - run
    - user: hdfs
    - group: hdfs
    - name: 'hdfs dfs -mkdir /tmp && hdfs dfs -chmod -R 1777 /tmp'
    - unless: 'hdfs dfs -test -d /tmp'
    - require:
      - cmd: hadoop-hdfs-namenode-svc

# HDFS MapReduce log directories
hdfs_mapreduce_log_dir:
  cmd:
    - run
    - user: hdfs
    - group: hdfs
    - name: 'hdfs dfs -mkdir -p {{ mapred_log_dir }} && hdfs dfs -chown yarn:hadoop {{ mapred_log_dir }}'
    - unless: 'hdfs dfs -test -d {{ mapred_log_dir }}'
    - require:
      - cmd: hadoop-hdfs-namenode-svc

# HDFS MapReduce var directories
hdfs_mapreduce_var_dir:
  cmd:
    - run
    - user: hdfs
    - group: hdfs
    - name: 'hdfs dfs -mkdir -p {{ mapred_staging_dir }} && hdfs dfs -chmod -R 1777 {{ mapred_staging_dir }} && hdfs dfs -chown mapred:hadoop {{ mapred_staging_dir }}'
    - unless: 'hdfs dfs -test -d {{ mapred_staging_dir }}'
    - require:
      - cmd: hadoop-hdfs-namenode-svc

{% if kms %}
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
      - cmd: hadoop-yarn-resourcemanager-svc
      - cmd: hadoop-mapreduce-historyserver-svc
{% endif %}

# create a user directory owned by the stack user
{% for user_obj in pillar.__stackdio__.users %}
{% set user = user_obj.username %}
hdfs_user_{{ user }}:
  cmd:
    - run
    - user: hdfs
    - group: hdfs
    - name: 'hdfs dfs -mkdir -p /user/{{ user }} && hdfs dfs -chown {{ user }}:{{ user }} /user/{{ user }}'
    - require:
      - service: hadoop-hdfs-namenode-svc
      {% if pillar.hdp2.security.enable %}
      - cmd: hdfs_kinit
      {% endif %}
{% endfor %}

##
# Starts yarn resourcemanager service.
#
# Depends on: JDK7
##
hadoop-yarn-resourcemanager-svc:
  cmd:
    - run
    - user: yarn
    - name: {{ yarn_script_dir }}/yarn-daemon.sh start resourcemanager
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/yarn/yarn-yarn-resourcemanager.pid'
    - env:
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - require: 
      - pkg: hadoop-yarn-resourcemanager
      - cmd: hadoop-hdfs-namenode-svc
      - cmd: hdfs_mapreduce_var_dir
      - cmd: hdfs_mapreduce_log_dir
      - cmd: hdfs_tmp_dir
      - cmd: kill-resourcemanager
      - file: bigtop_java_home
    - watch:
      - file: /etc/hadoop/conf

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
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/mapreduce/mapred-mapred-historyserver.pid'
    - env:
      - HADOOP_MAPRED_HOME: '{{ mapred_script_dir }}/..'
      - HADOOP_MAPRED_LOG_DIR: '/var/log/hadoop/mapreduce'
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - require:
      - pkg: hadoop-mapreduce-historyserver
      - cmd: hadoop-hdfs-namenode-svc
      - cmd: hdfs_mapreduce_var_dir
      - cmd: hdfs_mapreduce_log_dir
      - cmd: hdfs_tmp_dir
      - file: bigtop_java_home
      - cmd: kill-historyserver
    - watch:
      - file: /etc/hadoop/conf
