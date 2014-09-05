/etc/hive/conf/hive-site.xml:
  file:
    - managed
    - template: jinja
    - source: salt://hdp2/etc/hive/hive-site.xml
