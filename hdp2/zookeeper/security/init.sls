
include:
  - krb5
  - hdp2.security

generate_zookeeper_keytabs:
  cmd:
    - script 
    - source: salt://hdp2/zookeeper/security/generate_keytabs.sh
    - template: jinja
    - user: root
    - group: root
    - cwd: /etc/zookeeper/conf
    - unless: test -f /etc/zookeeper/conf/zookeeper.keytab
    - require:
      - module: load_admin_keytab
