{% set standby = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:hdp2.hadoop.yarn.standby-resourcemanager', 'grains.items', 'compound') %}

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
  {% if salt['pillar.get']('hdp2:resourcemanager:start_service', True) %}
  - hdp2.hadoop.yarn.resourcemanager.service
  {% endif %}
  {% if pillar.hdp2.encryption.enable %}
  - hdp2.hadoop.encryption
  {% endif %}
  {% if pillar.hdp2.security.enable %}
  - hdp2.hadoop.yarn.security
  {% endif %}

##
# Installs the yarn resourcemanager package.
#
# Depends on: JDK7
##
hadoop-yarn-resourcemanager:
  pkg:
    - installed
    - pkgs:
      - hadoop-yarn-resourcemanager
      - hadoop
      - hadoop-hdfs
      - hadoop-libhdfs
      - hadoop-yarn
      - hadoop-mapreduce
      - hadoop-client
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

{% if standby %}
# Only needed for HA
hadoop-yarn-proxyserver:
  pkg:
    - installed
    - pkgs:
      - hadoop-yarn-proxyserver
      - hadoop
      - hadoop-hdfs
      - hadoop-libhdfs
      - hadoop-yarn
      - hadoop-mapreduce
      - hadoop-client
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
{% endif %}
