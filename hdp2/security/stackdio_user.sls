{% if pillar.hdp2.security.enable %}
include:
  - krb5
  - hdp2.security

{% for user in pillar.__stackdio__.users %}
generate_keytab_{{ user.username }}:
  cmd:
    - script 
    - source: salt://hdp2/security/generate_user_keytab.sh
    - template: jinja
    - user: root
    - group: root
    - env:
      - STACKDIO_USER: {{ user.username }}
    - cwd: /home/{{ user.username }}
    - require:
      - module: load_admin_keytab
{% endfor %}
{% endif %}

