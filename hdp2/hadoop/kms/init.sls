include:
  - hdp2.repo
  - hdp2.hadoop.kms.conf
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
      - mysql-server
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

/usr/hdp/current/ranger-kms/ews/webapp/lib/mysql-connector-java.jar:
  file:
    - symlink
    - target: /usr/share/java/mysql-connector-java.jar
    - require:
      - pkg: ranger-kms

fix-kms-script:
  cmd:
    - run
    - name: chmod +x /usr/hdp/current/ranger-kms/ranger-kms
    - require:
      - pkg: ranger-kms
      - file: /usr/hdp/current/ranger-kms/ews/webapp/lib/mysql-connector-java.jar
