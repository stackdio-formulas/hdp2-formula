{% set kms = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:hdp2.hadoop.kms', 'grains.items', 'compound') %}

include:
  - hdp2.repo
  - hdp2.hadoop.conf
  - hdp2.landing_page
  {% if kms %}
  - hdp2.hadoop.encryption
  {% endif %}
  {% if salt['pillar.get']('hdp2:security:enable', False) %}
  - krb5
  - hdp2.security
  - hdp2.security.stackdio_user
  - hdp2.hadoop.security
  {% endif %}

hadoop-client: 
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
