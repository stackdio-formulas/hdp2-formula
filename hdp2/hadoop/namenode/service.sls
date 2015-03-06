{%- set standby = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:hdp2.hadoop.standby', 'grains.items', 'compound') -%}
{% set dfs_name_dir = salt['pillar.get']('hdp2:dfs:name_dir', '/mnt/hadoop/hdfs/nn') %}
{% set mapred_local_dir = salt['pillar.get']('hdp2:mapred:local_dir', '/mnt/hadoop/mapred/local') %}
{% set mapred_system_dir = salt['pillar.get']('hdp2:mapred:system_dir', '/hadoop/system/mapred') %}
{% set mapred_staging_dir = '/user/history' %}
{% set mapred_log_dir = '/var/log/hadoop-yarn' %}

# The scripts for starting services are in different places depending on the hdp version, so set them here
{% if int(pillar.hdp2.version.split('.')[1]) >= 2 %}
{% set hadoop_script_dir = '/usr/hdp/current/hadoop-hdfs-namenode/../hadoop/sbin' %}
{% set yarn_script_dir = '/usr/hdp/current/hadoop-yarn-resourcemanager/../hadoop/sbin' %}
{% set mapred_script_dir = '/usr/hdp/current/hadoop-mapreduce-historyserver/sbin' %}
{% else %}
{% set hadoop_script_dir = '/usr/lib/hadoop/sbin' %}
{% set yarn_script_dir = '/usr/lib/hadoop-yarn/sbin' %}
{% set mapred_script_dir = '/usr/lib/hadoop-mapreduce/sbin' %}
{% endif %}

##
# Standby NN specific SLS
##
{% if 'hdp2.hadoop.standby' in grains.roles %}
include:
  - hdp2.hadoop.standby.service
##
# END STANDBY NN
##

##
# Regular NN SLS
##
{% else %}

##
# Starts the namenode service.
#
# Depends on: JDK7
##
hadoop-hdfs-namenode-svc:
  cmd:
    - run
    - user: hdfs
    - name: {{ hadoop_script_dir }}/hadoop-daemon.sh start namenode
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/hdfs/hadoop-hdfs-namenode.pid'
    - require: 
      - pkg: hadoop-hdfs-namenode
      # Make sure HDFS is initialized before the namenode
      # is started
      - cmd: init_hdfs
      - file: bigtop_java_home
    - watch:
      - file: /etc/hadoop/conf

{% if standby %}
##
# Sets this namenode as the "Active" namenode
##
activate_namenode:
  cmd:
    - run
    - name: 'hdfs haadmin -transitionToActive nn1'
    - user: hdfs
    - group: hdfs
    - require:
      - cmd: hadoop-hdfs-namenode-svc
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: hdfs_kinit
      {% endif %}
{% endif %}

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
    - require: 
      - pkg: hadoop-yarn-resourcemanager
      - cmd: hadoop-hdfs-namenode-svc
      - cmd: hdfs_mapreduce_var_dir
      - cmd: hdfs_mapreduce_log_dir
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
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/yarn/mapred-mapred-historyserver.pid'
    - require:
      - pkg: hadoop-mapreduce-historyserver
      - cmd: hadoop-hdfs-namenode-svc
      - file: bigtop_java_home
    - watch:
      - file: /etc/hadoop/conf

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
{% if salt['pillar.get']('hdp2:security:enable', False) %}
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
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: hdfs_kinit
      {% endif %}
      {% if standby %}
      - cmd: activate_namenode 
      {% endif %}

# HDFS MapReduce log directories
hdfs_mapreduce_log_dir:
  cmd:
    - run
    - user: hdfs
    - group: hdfs
    - name: 'hdfs dfs -mkdir -p {{ mapred_log_dir }} && hdfs dfs -chown yarn:mapred {{ mapred_log_dir }}'
    - unless: 'hdfs dfs -test -d {{ mapred_log_dir }}'
    - require:
      - cmd: hadoop-hdfs-namenode-svc
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: hdfs_kinit
      {% endif %}
      {% if standby %}
      - cmd: activate_namenode 
      {% endif %}

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
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: hdfs_kinit
      {% endif %}
      {% if standby %}
      - cmd: activate_namenode 
      {% endif %}

# create a user directory owned by the stack user
{% set user = pillar.__stackdio__.username %}
hdfs_user_dir:
  cmd:
    - run
    - user: hdfs
    - group: hdfs
    - name: 'hdfs dfs -mkdir /user/{{ user }} && hdfs dfs -chown {{ user }}:{{ user }} /user/{{ user }}'
    - unless: 'hdfs dfs -test -d /user/{{ user }}'
    - require:
      - cmd: hadoop-yarn-resourcemanager-svc
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: hdfs_kinit
      {% endif %}
      {% if standby %}
      - cmd: activate_namenode 
      {% endif %}


#
##
# END REGULAR NAMENODE 
##
{% endif %}
