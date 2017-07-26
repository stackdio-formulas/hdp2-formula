
/etc/hadoop/conf:
  file:
    - recurse
    - source: salt://hdp2/etc/hadoop/conf
    - template: jinja
    - user: root
    - group: root
    - file_mode: 644
    {% if not pillar.hdp2.encryption.enable %}
    - exclude_pat: ssl-*.xml
    {% endif %}

/etc/hadoop/conf/secure/ssl-client.xml:
  file:
    - managed
    - source: salt://hdp2/etc/hadoop/conf/ssl-client.xml
    - user: root
    - group: root
    - mode: 644
    - makedirs: true
    - require:
      - file: /etc/hadoop/conf

hadoop-hdfs-dirs:
  cmd:
    - run
    - user: root
    - name: 'mkdir -p /var/{log,run}/hadoop-hdfs; chmod 775 /var/{log,run}/hadoop-hdfs; id -u hdfs &> /dev/null; if [ "$?" == "0" ]; then chown hdfs:hadoop /var/{log,run}/hadoop-hdfs; fi'
    - require:
      - file: /etc/hadoop/conf

hadoop-mapreduce-dirs:
  cmd:
    - run
    - user: root
    - name: 'mkdir -p /var/{log,run}/hadoop-mapreduce; chmod 775 /var/{log,run}/hadoop-mapreduce; id -u mapred &> /dev/null; if [ "$?" == "0" ]; then chown mapred:hadoop /var/{log,run}/hadoop-mapreduce; fi'
    - require:
      - file: /etc/hadoop/conf

hadoop-yarn-dirs:
  cmd:
    - run
    - user: root
    - name: 'mkdir -p /var/{log,run}/hadoop-yarn; chmod 775 /var/{log,run}/hadoop-yarn; id -u yarn &> /dev/null; if [ "$?" == "0" ]; then chown yarn:hadoop /var/{log,run}/hadoop-yarn; fi'
    - require:
      - file: /etc/hadoop/conf

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

bigtop-jsvc:
  pkg:
    - installed
    - require:
      - cmd: repo_placeholder

bigtop_java_home:
  file:
    - managed
    - name: /usr/lib/bigtop-utils/bigtop-detect-javahome
    - contents: 'export JAVA_HOME=/usr/java/latest'
    - user: root
    - group: root
    - require:
      - pkg: bigtop-jsvc
      - file: /etc/hadoop/conf/container-executor.cfg
      - file: /etc/hadoop/conf/log4j.properties
