{% if pillar.hdp2.security.enable %}
generate_hue_keytabs:
  cmd:
    - script 
    - source: salt://hdp2/hue/security/generate_keytabs.sh
    - template: jinja
    - user: root
    - group: root
    - cwd: /etc/hue
    - require:
      - module: load_admin_keytab
      - pkg: hue
{% endif %}
