include:
  - hdp2.repo
{#  - hdp2.hadoop.kms.conf#}
  - hdp2.landing_page
{% if salt['pillar.get']('hdp2:kms:start_service', True) %}
  - hdp2.hadoop.kms.service
{% endif %}
{% if salt['pillar.get']('hdp2:security:enable', False) %}
  - krb5
  - hdp2.security
  - hdp2.security.stackdio_user
  - hdp2.hadoop.kms.security
{% endif %}


ranger-kms:
  pkg:
    - installed
    - pkgs:
      - ranger-kms
      - ranger-admin
      {% if grains.os_family == 'RedHat' and grains.osmajorrelease == '7' %}
      - mariadb-server
      {% else %}
      - mysql-server
      {% endif %}
      - mysql-connector-java
    - require:
      - cmd: repo_placeholder
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - file: krb5_conf_file
      {% endif %}
    - require_in:
      - file: /etc/ranger/kms/conf
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hadoop_kms_keytabs
      {% endif %}

/etc/ranger/kms/conf/core-site.xml:
  file:
    - managed
    - template: jinja
    - source: salt://hdp2/etc/hadoop/conf/core-site.xml
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: ranger-kms
