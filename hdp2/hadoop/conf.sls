
/etc/hadoop/conf:
  file:
    - recurse
    - source: salt://hdp2/etc/hadoop/conf
    - template: jinja
    - user: root
    - group: root
    - file_mode: 644
    {% if pillar.hdp2.encryption.enable %}
    - exclude_pat: .*.swp
    {% else %}
    - exclude_pat: ssl-*.xml
    {% endif %}

/etc/hadoop/conf/container-executor.cfg:
  file:
    - managed
    - mode: 400
    - replace: false
    - user: root
    - group: root
    - require:
      - file: /etc/hadoop/conf

/etc/hadoop/conf/log4j.properties:
  file:
    - replace
    - pattern: 'maxbackupindex=20'
    - repl: 'maxbackupindex={{ pillar.hdp2.max_log_index }}'
    - require:
      - file: /etc/hadoop/conf

/etc/hadoop/conf/mapred-env.sh:
  file:
    - append
    - text: 'export HADOOP_MAPRED_LOG_DIR=/var/log/hadoop-mapreduce; export HADOOP_MAPRED_PID_DIR=/var/run/hadoop-mapreduce'
    - require:
      - file: /etc/hadoop/conf

bigtop_java_home:
  file:
    - managed
    - name: /usr/lib/bigtop-utils/bigtop-detect-javahome
    - contents: 'export JAVA_HOME=/usr/java/latest'
    - user: root
    - group: root
    - require:
      - file: /etc/hadoop/conf/container-executor.cfg
      - file: /etc/hadoop/conf/log4j.properties
