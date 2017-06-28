{% set standby = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:hdp2.hadoop.hdfs.standby-namenode', 'grains.items', 'compound') %}

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
  - hdp2.hadoop.hdfs.namenode.service
  {% endif %}
  {% if pillar.hdp2.encryption.enable %}
  - hdp2.hadoop.encryption
  {% endif %}
  {% if pillar.hdp2.security.enable %}
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
      {% if pillar.hdp2.security.enable %}
      - file: krb5_conf_file
      {% endif %}
    - require_in:
      - file: /etc/hadoop/conf
      - cmd: hdfs_log_dir
      {% if pillar.hdp2.encryption.enable %}
      - file: /etc/hadoop/conf/ca
      {% endif %}
      {% if pillar.hdp2.security.enable %}
      - cmd: generate_hadoop_keytabs
      {% endif %}

{% if standby %}
# Only needed for HA
hadoop-hdfs-zkfc:
  pkg:
    - installed
    - require:
      - cmd: repo_placeholder
      {% if pillar.hdp2.security.enable %}
      - file: krb5_conf_file
      {% endif %}
    - require_in:
      - file: /etc/hadoop/conf
      {% if pillar.hdp2.security.enable %}
      - cmd: generate_hadoop_keytabs
      {% endif %}
{% endif %}
