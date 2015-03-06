{% set journal_dir = salt['pillar.get']('hdp2:dfs:journal_dir', '/mnt/hadoop/hdfs/jn') %}

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
hadoop-hdfs-journalnode-svc:
  cmd:
    - run
    - user: hdfs
    - name: {{ hadoop_script_dir }}/hadoop-daemon.sh start namenode
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/hdfs/hadoop-hdfs-journalnode.pid'
    - require:
      - pkg: hadoop-hdfs-journalnode
      - file: bigtop_java_home
      - cmd: hdp2_journal_dir
    - watch:
      - file: /etc/hadoop/conf

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
