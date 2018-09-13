
include:
  - hdp2.repo
  - hdp2.landing_page
  {% if salt['pillar.get']('hdp2:spark:start_service', True) %}
  - hdp2.spark.historyserver.service
  {% endif %}
  {% if pillar.hdp2.security.enable %}
  - hdp2.spark.security
  {% endif %}


spark:
  pkg:
    - installed
    - require:
      - cmd: repo_placeholder
