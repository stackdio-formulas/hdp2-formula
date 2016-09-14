{% set dfs_name_dir = salt['pillar.get']('hdp2:dfs:name_dir', '/mnt/hadoop/hdfs/nn') %}
{% set mapred_local_dir = salt['pillar.get']('hdp2:mapred:local_dir', '/mnt/hadoop/mapred/local') %}
{% set mapred_system_dir = salt['pillar.get']('hdp2:mapred:system_dir', '/hadoop/system/mapred') %}
{% set mapred_staging_dir = '/user/history' %}
{% set mapred_log_dir = '/var/log/hadoop-yarn' %}
{% set standby = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:hdp2.hadoop.standby-namenode', 'grains.items', 'compound') %}
{% set kms = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:hdp2.hadoop.kms', 'grains.items', 'compound') %}

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
  - hdp2.hadoop.namenode.service
  {% endif %}
  {% if kms %}
  - hdp2.hadoop.encryption
  {% endif %}
  {% if salt['pillar.get']('hdp2:security:enable', False) %}
  - krb5
  - hdp2.security
  - hdp2.security.stackdio_user
  - hdp2.hadoop.security
  {% endif %}

hadoop-hdfs-namenode:
  pkg:
    - installed
    - require:
      - cmd: repo_placeholder
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - file: krb5_conf_file
      {% endif %}
    - require_in:
      - file: /etc/hadoop/conf
      - cmd: hdfs_log_dir
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hadoop_keytabs
      {% endif %}

{% if standby %}
# Only needed for HA
hadoop-hdfs-zkfc:
  pkg:
    - installed
    - require:
      - cmd: repo_placeholder
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - file: krb5_conf_file
      {% endif %}
    - require_in:
      - file: /etc/hadoop/conf
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hadoop_keytabs
      {% endif %}
{% endif %}

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
      - file: krb5_conf_file
      {% endif %}
    - require_in:
      - file: /etc/hadoop/conf
      - cmd: hdfs_log_dir
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hadoop_keytabs
      {% endif %}

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
      - file: krb5_conf_file
      {% endif %}
    - require_in:
      - file: /etc/hadoop/conf
      - cmd: hdfs_log_dir
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hadoop_keytabs
      {% endif %}
