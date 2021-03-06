{% if pillar.hdp2.security.enable %}
generate_hadoop_kms_keytabs:
  cmd:
    - script
    - source: salt://hdp2/hadoop/kms/security/generate_keytabs.sh
    - template: jinja
    - user: root
    - group: root
    - cwd: /etc/ranger/kms/conf
    - require:
      - module: load_admin_keytab
      - cmd: generate_http_keytab
{% endif %}
