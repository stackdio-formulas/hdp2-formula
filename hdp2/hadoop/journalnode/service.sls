{% set journal_dir = salt['pillar.get']('hdp2:dfs:journal_dir', '/mnt/hadoop/hdfs/jn') %}
{% set kms = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:hdp2.hadoop.kms', 'grains.items', 'compound') %}

# The scripts for starting services are in different places depending on the hdp version, so set them here
{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set hadoop_script_dir = '/usr/hdp/current/hadoop-hdfs-journalnode/../hadoop/sbin' %}
{% else %}
{% set hadoop_script_dir = '/usr/lib/hadoop/sbin' %}
{% endif %}

##
# Starts the journalnode service.
#
# Depends on: JDK7
##

kill-journalnode:
  cmd:
    - run
    - user: hdfs
    - name: {{ hadoop_script_dir }}/hadoop-daemon.sh stop journalnode
    - onlyif: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/hdfs/hadoop-hdfs-journalnode.pid'
    - env:
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - require:
      - pkg: hadoop-hdfs-journalnode

# Make sure the journal data directory exists if necessary
hdp2_journal_dir:
  cmd:
    - run
    - name: 'mkdir -p {{ journal_dir }} && chown -R hdfs:hdfs `dirname {{ journal_dir }}`'
    - unless: 'test -d {{ journal_dir }}'
    - require:
      - pkg: hadoop-hdfs-journalnode
      - file: bigtop_java_home
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hadoop_keytabs
      {% endif %}

hadoop-hdfs-journalnode-svc:
  cmd:
    - run
    - user: hdfs
    - name: {{ hadoop_script_dir }}/hadoop-daemon.sh start journalnode
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/hdfs/hadoop-hdfs-journalnode.pid'
    - env:
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - require:
      - pkg: hadoop-hdfs-journalnode
      - file: bigtop_java_home
      - cmd: hdp2_journal_dir
      {% if kms %}
      - cmd: chown-keystore
      {% endif %}
      - file: /etc/hadoop/conf
      - cmd: kill-journalnode
    - watch:
      - file: /etc/hadoop/conf
