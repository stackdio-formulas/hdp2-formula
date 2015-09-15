/etc/ranger/kms/conf:
  file:
    - recurse
    - source: salt://hdp2/etc/ranger/kms/conf
    - template: jinja
    - user: root
    - group: root
    - file_mode: 644
    - exclude_pat: '.*.swp'

/usr/hdp/current/ranger-kms/ews/ranger-kms-site.xml:
  file:
    - symlink
    - target: /etc/ranger/kms/conf/kms-site.xml
    - require:
      - file: /etc/ranger/kms/conf
