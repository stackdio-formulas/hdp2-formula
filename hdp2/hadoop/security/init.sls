{% if pillar.hdp2.security.enable %}
generate_hadoop_keytabs:
  cmd:
    - script 
    - source: salt://hdp2/hadoop/security/generate_keytabs.sh
    - template: jinja
    - user: root
    - group: root
    - cwd: /etc/hadoop/conf
    - require:
      - module: load_admin_keytab
      - cmd: generate_http_keytab
{% endif %}
