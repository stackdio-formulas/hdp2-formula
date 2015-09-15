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
    - require:
      - cmd: repo_placeholder
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - file: krb5_conf_file
      {% endif %}
    - require_in:
      - file: /etc/hadoop-kms/conf
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hadoop_kms_keytabs
      {% endif %}

fix-kms-script:
  cmd:
    - run
    - name: chmod +x /usr/hdp/current/ranger-kms/ranger-kms
    - require:
      - pkg: ranger-kms


/etc/init.d/ranger-kms:
  file:
    - symlink
    - target: /usr/hdp/current/ranger-kms/ranger-kms-initd
    - require:
      - pkg: ranger-kms
      - cmd: fix-kms-script
