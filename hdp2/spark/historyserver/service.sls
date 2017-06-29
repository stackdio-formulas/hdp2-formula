

# The scripts for starting services are in different places depending on the hdp version, so set them here
{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set spark_script_dir = '/usr/hdp/current/spark-historyserver/../spark/sbin' %}
{% else %}
{% set spark_script_dir = '/usr/lib/spark/sbin' %}
{% endif %}


kill-historyserver:
  cmd:
    - run
    - user: spark
    - name: {{ spark_script_dir }}/stop-history-server.sh
    - onlyif: '. /etc/init.d/functions && pidofproc -p /var/run/spark/spark-spark-org.apache.spark.deploy.history.HistoryServer-1.pid'
    - require:
      - pkg: spark


# When security is enabled, we need to get a kerberos ticket
# for the hdfs principal so that any interaction with HDFS
# through the hadoop client may authorize successfully.
# NOTE this means that any 'hdfs dfs' commands will need
# to require this state to be sure we have a krb ticket
{% if pillar.hdp2.security.enable %}
hdfs_kinit:
  cmd:
    - run
    - name: 'kinit -kt /etc/hadoop/conf/hdfs.keytab hdfs/{{ grains.fqdn }}'
    - user: hdfs
    - group: hdfs
    - env:
      - KRB5_CONFIG: '{{ pillar.krb5.conf_file }}'
    - require_in:
      - cmd: history-dir

hdfs_kdestroy:
  cmd:
    - run
    - name: 'kdestroy'
    - user: hdfs
    - group: hdfs
    - env:
      - KRB5_CONFIG: '{{ pillar.krb5.conf_file }}'
    - require:
      - cmd: hdfs_kinit
      - cmd: history-dir
{% endif %}


history-dir:
  cmd:
    - run
    - user: hdfs
    - group: hdfs
    - name: 'hdfs dfs -mkdir -p /user/spark/applicationHistory && hdfs dfs -chown -R spark:spark /user/spark && hdfs dfs -chmod 1777 /user/spark/applicationHistory'
    - require:
      - pkg: spark


/etc/spark/conf/spark-defaults.conf:
  file:
    - managed
    - user: root
    - group: root
    - mode: 644
    - source: salt://hdp2/etc/spark/spark-defaults.conf
    - template: jinja
    - require:
      - pkg: spark

/etc/spark/conf/spark-env.sh:
  file:
    - append
    - text:
      - export SPARK_LOG_DIR=/var/log/spark
      - export SPARK_PID_DIR=/var/run/spark
      {% if pillar.hdp2.security.enable %}
      {% from 'krb5/settings.sls' import krb5 with context %}
      - 'SPARK_HISTORY_OPTS="$SPARK_HISTORY_OPTS -Dspark.history.kerberos.enabled=true -Dspark.history.kerberos.principal=spark/{{ grains.fqdn }}@{{ krb5.realm }} -Dspark.history.kerberos.keytab=/etc/spark/conf/spark.keytab -Djava.security.krb5.conf={{ pillar.krb5.conf_file }}"'
      {% endif %}
    - require:
      - pkg: spark
    - watch_in:
      - service: spark-history-server-svc

spark-history-server-svc:
  cmd:
    - run
    - user: spark
    - name: {{ spark_script_dir }}/start-history-server.sh
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/spark/spark-spark-org.apache.spark.deploy.history.HistoryServer-1.pid'
    - require:
      - pkg: spark
      - cmd: kill-historyserver
      - cmd: history-dir
      {% if pillar.hdp2.security.enable %}
      - cmd: generate_spark_keytabs
      {% endif %}
    - watch:
      - file: /etc/spark/conf/spark-defaults.conf
      - file: /etc/spark/conf/spark-env.sh
