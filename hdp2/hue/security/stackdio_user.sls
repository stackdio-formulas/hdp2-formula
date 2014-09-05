{% if salt['pillar.get']('hdp2:security:enable', False) %}
include:
  - krb5
  - hdp2.security

generate_user_keytab:
  cmd:
    - script 
    - source: salt://hdp2/security/generate_user_keytab.sh
    - template: jinja
    - user: root
    - group: root
    - cwd: /home/{{ pillar.__stackdio__.username }}
    - require:
      - module: load_admin_keytab
{% endif %}

