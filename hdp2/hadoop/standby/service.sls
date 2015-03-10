{% set dfs_name_dir = salt['pillar.get']('hdp2:dfs:name_dir', '/mnt/hadoop/hdfs/nn') %}

# The scripts for starting services are in different places depending on the hdp version, so set them here
{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set hadoop_script_dir = '/usr/hdp/current/hadoop-hdfs-namenode/../hadoop/sbin' %}
{% else %}
{% set hadoop_script_dir = '/usr/lib/hadoop/sbin' %}
{% endif %}

##
# Starts the namenode service.
#
# Depends on: JDK7
##
hadoop-hdfs-namenode-svc:
  cmd:
    - run
    - user: hdfs
    - name: export HADOOP_LIBEXEC_DIR={{ hadoop_script_dir }}/../libexec && {{ hadoop_script_dir }}/hadoop-daemon.sh start namenode
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/hdfs/hadoop-hdfs-namenode.pid'
    - require:
      - pkg: hadoop-hdfs-namenode
      - cmd: init_standby_namenode
      - file: bigtop_java_home
      - user: mapred_user
    - watch:
      - file: /etc/hadoop/conf

start_zkfc:
  cmd:
    - run
    - user: hdfs
    - name: {{ hadoop_script_dir }}/hadoop-daemon.sh start zkfc -formatZK
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/hdfs/hadoop-hdfs-zkfc.pid'
    - require:
      - cmd: hadoop-hdfs-namenode-svc
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: hdfs_kinit
      {% endif %}

##
# Sets this namenode as the "Standby" namenode
##
#activate_standby:
#  cmd:
#    - run
#    - name: 'hdfs haadmin -transitionToStandby nn2'
#    - user: hdfs
#    - group: hdfs
#    - require:
#      - cmd: hadoop-hdfs-namenode-svc

# Make sure the namenode metadata directory exists
# and is owned by the hdfs user
hdp2_dfs_dirs:
  cmd:
    - run
    - name: 'mkdir -p {{ dfs_name_dir }} && chown -R hdfs:hdfs `dirname {{ dfs_name_dir }}`'
    - unless: 'test -d {{ dfs_name_dir }}'
    - require:
      - pkg: hadoop-hdfs-namenode
      - file: bigtop_java_home

# Initialize the standby namenode, which will sync the configuration
# and metadata from the active namenode
init_standby_namenode:
  cmd:
    - run
    - user: hdfs
    - group: hdfs
    - name: 'hdfs namenode -bootstrapStandby -force -nonInteractive'
    - unless: 'test -d {{ dfs_name_dir }}/current'
    - require:
      - cmd: hdp2_dfs_dirs
    {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hadoop_keytabs
    {% endif %}
