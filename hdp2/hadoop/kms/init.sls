include:
  - hdp2.repo
  - hdp2.landing_page
{% if salt['pillar.get']('hdp2:kms:start_service', True) %}
  - hdp2.hadoop.kms.service
{% endif %}
{% if pillar.hdp2.security.enable %}
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
      {% if pillar.hdp2.security.enable %}
      - file: krb5_conf_file
      {% endif %}
    - require_in:
      {% if pillar.hdp2.security.enable %}
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

/usr/hdp/current/ranger-admin/install.properties:
  file:
    - managed
    - template: jinja
    - source: salt://hdp2/hadoop/kms/install.properties-admin
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: ranger-kms

/usr/hdp/current/ranger-kms/install.properties:
  file:
    - managed
    - template: jinja
    - source: salt://hdp2/hadoop/kms/install.properties-kms
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: ranger-kms
