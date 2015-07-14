# 
# Install the Hue package
#
include:
  - hdp2.repo
  - hdp2.hadoop.client
  - hdp2.landing_page
  - hdp2.hue.plugins
{% if salt['pillar.get']('hdp2:hue:start_service', True) %}
  - hdp2.hue.service
{% endif %}
{% if salt['pillar.get']('hdp2:security:enable', False) %}
  - krb5
  - hdp2.security
  - hdp2.hue.security
{% endif %}

hue:
  pkg:
    - installed
    - pkgs:
      - hue
      - hue-server
      {% if grains['os_family'] == 'RedHat' %}
      - hue-plugins
      {% endif %}
    - require:
      - cmd: repo_placeholder

/mnt/tmp/hadoop:
  file:
    - directory
    - makedirs: true
    - mode: 777
