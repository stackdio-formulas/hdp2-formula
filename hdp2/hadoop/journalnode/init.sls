# From cloudera, hdp2 requires JDK7, so include it along with the 
# hdp2 repository to install their packages.

include:
  - hdp2.repo
  - hdp2.hadoop.conf
  - hdp2.landing_page
  {% if salt['pillar.get']('hdp2:journalnode:start_service', True) %}
  - hdp2.hadoop.journalnode.service
  {% endif %}
  {% if salt['pillar.get']('hdp2:security:enable', False) %}
  - krb5
  - hdp2.security
  - hdp2.hadoop.security
  {% endif %}

{% if salt['pillar.get']('hdp2:security:enable', False) %}
extend:
  load_admin_keytab:
    module:
      - require:
        - file: /etc/krb5.conf
        - file: /etc/hadoop/conf
  generate_hadoop_keytabs:
    cmd:
      - require:
        - module: load_admin_keytab
{% endif %}

##
# Installs the journalnode package for high availability
#
# Depends on: JDK7
##
hadoop-hdfs-journalnode:
  pkg:
    - installed
    - require:
      - cmd: repo_placeholder
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - file: /etc/krb5.conf
      {% endif %}
    - require_in:
      - file: /etc/hadoop/conf
      - cmd: hdfs_log_dir
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hadoop_keytabs
      {% endif %}
