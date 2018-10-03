
##
# Standby NameNode
##

include:
  - hdp2.repo
  - hdp2.hadoop.conf
  - hdp2.landing_page
  {% if salt['pillar.get']('hdp2:resourcemanager:start_service', True) %}
  - hdp2.hadoop.yarn.standby-resourcemanager.service
  {% endif %}
  {% if pillar.hdp2.encryption.enable %}
  - hdp2.hadoop.encryption
  {% endif %}
  {% if pillar.hdp2.security.enable %}
  - hdp2.hadoop.yarn.security
  {% endif %}

hadoop-yarn-resourcemanager:
  pkg.installed:
    - pkgs:
      - hadoop-yarn-resourcemanager
      - hadoop
      - hadoop-hdfs
      - hadoop-libhdfs
      - hadoop-yarn
      - hadoop-mapreduce
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
