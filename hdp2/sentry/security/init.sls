generate_sentry_keytabs:
  cmd:
    - script 
    - source: salt://hdp2/sentry/security/generate_keytabs.sh
    - template: jinja
    - user: root
    - group: root
    - cwd: /etc/sentry/conf
    - require:
      - module: load_admin_keytab
