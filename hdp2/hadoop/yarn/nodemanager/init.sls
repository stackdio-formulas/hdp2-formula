
# From cloudera, CDH5 requires JDK7, so include it along with the 
# CDH5 repository to install their packages.
include:
  - hdp2.repo
  - hdp2.hadoop.conf
  - hdp2.landing_page
  {% if salt['pillar.get']('hdp2:nodemanager:start_service', True) %}
  - hdp2.hadoop.yarn.nodemanager.service
  {% endif %}
  {% if pillar.hdp2.encryption.enable %}
  - hdp2.hadoop.encryption
  {% endif %}
  {% if pillar.hdp2.security.enable %}
  - hdp2.hadoop.yarn.security
  {% endif %}

##
# Installs the yarn nodemanager service
#
# Depends on: JDK7
##
hadoop-yarn-nodemanager:
  pkg.installed:
    - pkgs:
      - hadoop-yarn-nodemanager
      - hadoop
      - hadoop-hdfs
      - hadoop-libhdfs
      - hadoop-yarn
      - hadoop-mapreduce
      - hadoop-client
      - spark
      - spark-yarn-shuffle
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

spark-shuffle-jar:
  cmd.run:
    - user: root
    - name: ln -sf /usr/hdp/current/spark-client/aux/spark-*-yarn-shuffle.jar /usr/hdp/current/hadoop-yarn-nodemanager/lib/
    - require:
      - pkg: hadoop-yarn-nodemanager
