{% set dfs_name_dir = salt['pillar.get']('hdp2:dfs:name_dir', '/mnt/hadoop/hdfs/nn') %}
{% set mapred_local_dir = salt['pillar.get']('hdp2:mapred:local_dir', '/mnt/hadoop/mapred/local') %}
{% set mapred_system_dir = salt['pillar.get']('hdp2:mapred:system_dir', '/hadoop/system/mapred') %}
{% set mapred_staging_dir = '/user/history' %}
{% set mapred_log_dir = '/var/log/hadoop-yarn' %}

##
# Adding high-availability to the mix makes things a bit more complicated.
# First, the NN and HA NN need to connect and sync up before anything else
# happens. Right now, that's hard since we can't parallelize the two
# state runs...so, what we have to do instead is make the HA NameNode also
# be a regular NameNode, and tweak the regular SLS to install both, at the
# same time.
##

##
# This is a HA NN, reduce the normal NN state down to all we need
# for the standby NameNode
##

include:
  - hdp2.repo
  - hdp2.hadoop.conf
  - hdp2.landing_page
  {% if salt['pillar.get']('hdp2:namenode:start_service', True) %}
  {% if 'hdp2.hadoop.standby' in grains.roles %}
  - hdp2.hadoop.standby.service
  {% else %}
  - hdp2.hadoop.namenode.service
  {% endif %}
  {% endif %}
  {% if salt['pillar.get']('hdp2:security:enable', False) %}
  - krb5
  - hdp2.security
  - hdp2.security.stackdio_user
  - hdp2.hadoop.security
  {% endif %}

{% if 'hdp2.hadoop.standby' in grains.roles %}

extend:
  /etc/hadoop/conf:
    file:
      - require:
        - pkg: hadoop-hdfs-namenode

hadoop-hdfs-namenode:
  pkg:
    - installed 
    - require:
      - cmd: repo_placeholder
    - require_in:
      - cmd: hdfs_log_dir

# we need a mapred user on the standby namenode for job history to work; if the
# namenode state is not included we want to add it manually
mapred_group:
  group:
    - present
    - name: mapred

hadoop_group:
  group:
    - present
    - name: hadoop

mapred_user:
  user:
    - present
    - name: mapred
    - fullname: Hadoop MapReduce
    - shell: /bin/bash
    - home: /var/lib/hadoop-mapreduce
    - groups:
      - mapred
      - hadoop
    - require:
      - group: mapred_group
      - group: hadoop_group

##
# END HA NN
##

# NOT a HA NN...continue like normal with the rest of the state
{% else %}

extend:
  /etc/hadoop/conf:
    file:
      - require:
        - pkg: hadoop-hdfs-namenode
        - pkg: hadoop-yarn-resourcemanager 
        - pkg: hadoop-mapreduce-historyserver
  {% if salt['pillar.get']('hdp2:security:enable', False) %}
  load_admin_keytab:
    module:
      - require:
        - file: /etc/krb5.conf
        - file: /etc/hadoop/conf
  generate_hadoop_keytabs:
    cmd:
      - require:
        - pkg: hadoop-hdfs-namenode
        - pkg: hadoop-yarn-resourcemanager
        - pkg: hadoop-mapreduce-historyserver
        - module: load_admin_keytab
  {% endif %}

##
# Installs the namenode package.
#
# Depends on: JDK7
##
hadoop-hdfs-namenode:
  pkg:
    - installed 
    - require:
      - cmd: repo_placeholder
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - file: /etc/krb5.conf
      {% endif %}
    - require_in:
      - cmd: hdfs_log_dir

##
# Installs the yarn resourcemanager package.
#
# Depends on: JDK7
##
hadoop-yarn-resourcemanager:
  pkg:
    - installed
    - require:
      - cmd: repo_placeholder
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - file: /etc/krb5.conf
      {% endif %}
    - require_in:
      - cmd: hdfs_log_dir

##
# Installs the mapreduce historyserver package.
#
# Depends on: JDK7
##
hadoop-mapreduce-historyserver:
  pkg:
    - installed
    - require:
      - cmd: repo_placeholder
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - file: /etc/krb5.conf
      {% endif %}
    - require_in:
      - cmd: hdfs_log_dir

{% endif %}
##
# END OF REGULAR NAMENODE
##
