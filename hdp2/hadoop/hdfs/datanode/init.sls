
# From cloudera, CDH5 requires JDK7, so include it along with the 
# CDH5 repository to install their packages.
include:
  - hdp2.repo
  - hdp2.hadoop.conf
  - hdp2.landing_page
  - hdp2.hadoop.client
  {% if salt['pillar.get']('hdp2:datanode:start_service', True) %}
  - hdp2.hadoop.hdfs.datanode.service
  {% endif %}
  {% if pillar.hdp2.encryption.enable %}
  - hdp2.hadoop.encryption
  {% endif %}
  {% if pillar.hdp2.security.enable %}
  - hdp2.hadoop.hdfs.security
  {% endif %}

##
# Installs the datanode service
#
# Depends on: JDK7
#
##
hadoop-hdfs-datanode:
  pkg:
    - installed 
    - require:
      - cmd: repo_placeholder
      {% if pillar.hdp2.security.enable %}
      - file: krb5_conf_file
      {% endif %}
    - require_in:
      - file: /etc/hadoop/conf
      {% if pillar.hdp2.encryption.enable %}
      - file: /etc/hadoop/conf/ca
      {% endif %}
      {% if pillar.hdp2.security.enable %}
      - cmd: generate_hadoop_keytabs
      {% endif %}
