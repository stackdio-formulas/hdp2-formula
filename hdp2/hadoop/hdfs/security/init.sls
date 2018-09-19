
include:
  - krb5
  - hdp2.security
  - hdp2.security.stackdio_user

generate_hadoop_keytabs:
  cmd:
    - script 
    - source: salt://hdp2/hadoop/hdfs/security/generate_keytabs.sh
    - template: jinja
    - user: root
    - group: root
    - cwd: /etc/hadoop/conf
    - unless: test -f /etc/hadoop/conf/hdfs.keytab
    - require:
      - module: load_admin_keytab
      - cmd: generate_http_keytab

