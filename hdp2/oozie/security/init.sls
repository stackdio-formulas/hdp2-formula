{% if salt['pillar.get']('hdp2:security:enable', False) %}
generate_oozie_keytabs:
  cmd:
    - script 
    - source: salt://hdp2/oozie/security/generate_keytabs.sh
    - template: jinja
    - user: root
    - group: root
    - cwd: /etc/oozie/conf
    - require:
      - module: load_admin_keytab
{% endif %}
