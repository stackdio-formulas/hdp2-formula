hdfs_log_dir:
  cmd:
    - run
    - name: 'mkdir -p /var/log/hadoop/hdfs && chown hdfs:hadoop /var/log/hadoop/hdfs'

{% if 'hdp2.hadoop.standby' not in grains.roles %}
mapred_log_dir:
  cmd:
    - run
    - name: 'mkdir -p /var/log/hadoop/mapreduce && chown mapred:hadoop /var/log/hadoop/mapreduce'
    - require:
      - cmd: hdfs_log_dir
    - require_in:
      - /etc/hadoop/conf

yarn_log_dir:
  cmd:
    - run
    - name: 'mkdir -p /var/log/hadoop/yarn && chown yarn:hadoop /var/log/hadoop/yarn'
    - require:
      - cmd: mapred_log_dir
    - require_in:
      - /etc/hadoop/conf
{% endif %}

/etc/hadoop/conf:
  file:
    - recurse
    - source: salt://hdp2/etc/hadoop/conf
    - template: jinja
    - user: root
    - group: root
    - file_mode: 644
    - exclude_pat: '.*.swp'
    - require:
      - cmd: hdfs_log_dir

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

/etc/hadoop/conf/hadoop-env.sh:
  file:
    - append
    - text: 'export HADOOP_LOG_DIR=/var/log/hadoop/$USER; export HADOOP_PID_DIR=/var/run/hadoop/$USER'
    - require:
      - file: /etc/hadoop/conf

/etc/hadoop/conf/mapred-env.sh:
  file:
    - append
    - text: 'export HADOOP_MAPRED_LOG_DIR=/var/log/hadoop/mapreduce; export HADOOP_MAPRED_PID_DIR=/var/run/hadoop/mapreduce'
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
