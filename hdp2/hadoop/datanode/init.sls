
# From cloudera, CDH5 requires JDK7, so include it along with the 
# CDH5 repository to install their packages.
include:
  - hdp2.repo
  - hdp2.hadoop.conf
  - hdp2.landing_page
  - hdp2.hadoop.client
{% if salt['pillar.get']('hdp2:datanode:start_service', True) %}
  - hdp2.hadoop.datanode.service
{% endif %}
{% if salt['pillar.get']('hdp2:security:enable', False) %}
  - krb5
  - hdp2.security
  - hdp2.security.stackdio_user
  - hdp2.hadoop.security
{% endif %}

extend:
  /etc/hadoop/conf:
    file:
      - require:
        - pkg: hadoop-hdfs-datanode
        - pkg: hadoop-yarn-nodemanager
        - pkg: hadoop-mapreduce
{% if salt['pillar.get']('hdp2:security:enable', False) %}
  load_admin_keytab:
    module:
      - require:
        - file: /etc/krb5.conf
        - file: /etc/hadoop/conf
  generate_hadoop_keytabs:
    cmd:
      - require:
        - pkg: hadoop-hdfs-datanode
        - pkg: hadoop-yarn-nodemanager
        - pkg: hadoop-mapreduce
        - module: load_admin_keytab
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
{% if salt['pillar.get']('hdp2:security:enable', False) %}
      - file: /etc/krb5.conf
{% endif %}

{% if salt['pillar.get']('hdp2:security:enable', False) %}
/etc/default/hadoop-hdfs-datanode:
  file:
    - managed
    - source: salt://hdp2/etc/default/hadoop-hdfs-datanode
    - template: jinja
    - makedirs: true
    - user: root
    - group: root
    - file_mode: 644
    - require:
      - pkg: hadoop-hdfs-datanode
{% endif %}

##
# Installs the yarn nodemanager service
#
# Depends on: JDK7
##
hadoop-yarn-nodemanager:
  pkg:
    - installed 
    - require:
      - cmd: repo_placeholder
{% if salt['pillar.get']('hdp2:security:enable', False) %}
      - file: /etc/krb5.conf
{% endif %}

##
# Installs the mapreduce service
#
# Depends on: JDK7
##
hadoop-mapreduce:
  pkg:
    - installed
    - require:
      - cmd: repo_placeholder
{% if salt['pillar.get']('hdp2:security:enable', False) %}
      - file: /etc/krb5.conf
{% endif %}


