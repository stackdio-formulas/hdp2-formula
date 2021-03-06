
##
# Standby NameNode
##

include:
  - hdp2.repo
  - hdp2.hadoop.conf
  - hdp2.landing_page
  {% if salt['pillar.get']('hdp2:namenode:start_service', True) %}
  - hdp2.hadoop.hdfs.standby-namenode.service
  {% endif %}
  {% if pillar.hdp2.encryption.enable %}
  - hdp2.hadoop.encryption
  {% endif %}
  {% if pillar.hdp2.security.enable %}
  - hdp2.hadoop.hdfs.security
  {% endif %}

hadoop-hdfs-namenode:
  pkg.installed:
    - pkgs:
      - hadoop-hdfs-namenode
      - hadoop-hdfs-zkfc
      - hadoop
      - hadoop-hdfs
      - hadoop-mapreduce
      - hadoop-libhdfs
      - hadoop-client
      - spark
      - openssl
    - require:
      - cmd: repo_placeholder
      {% if pillar.hdp2.security.enable %}
      - file: krb5_conf_file
      {% endif %}
    - require_in:
      - file: /etc/hadoop/conf
      {% if pillar.hdp2.encryption.enable %}
      - file: /etc/hadoop/conf/hadoop.key
      {% endif %}
      {% if pillar.hdp2.security.enable %}
      - cmd: generate_hadoop_keytabs
      {% endif %}
