include:
  - krb5
  - hdp2.security

generate_hbase_keytabs:
  cmd:
    - script
    - source: salt://hdp2/hbase/security/generate_keytabs.sh
    - template: jinja
    - user: root
    - group: root
    - cwd: /etc/hbase/conf
    - unless: test -f /etc/hbase/conf/hbase.keytab
    - require:
      - module: load_admin_keytab
