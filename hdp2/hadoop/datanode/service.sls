{% set mapred_local_dir = salt['pillar.get']('hdp2:mapred:local_dir', '/mnt/yarn') %}
{% set dfs_data_dir = salt['pillar.get']('hdp2:dfs:data_dir', '/mnt/hadoop/hdfs/data') %}

# The scripts for starting services are in different places depending on the hdp version, so set them here
{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set hadoop_script_dir = '/usr/hdp/current/hadoop-hdfs-datanode/../hadoop/sbin' %}
{% set yarn_script_dir = '/usr/hdp/current/hadoop-yarn-nodemanager/../hadoop/sbin' %}
{% else %}
{% set hadoop_script_dir = '/usr/lib/hadoop/sbin' %}
{% set yarn_script_dir = '/usr/lib/hadoop-yarn/sbin' %}
{% endif %}


##
# Starts the datanode service
#
# Depends on: JDK7
#
##
hadoop-hdfs-datanode-svc:
  cmd:
    - run
    - user: hdfs
    - name: export HADOOP_LIBEXEC_DIR={{ hadoop_script_dir }}/../libexec && {{ hadoop_script_dir }}/hadoop-daemon.sh start datanode
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/hdfs/hadoop-hdfs-datanode.pid'
    - require: 
      - pkg: hadoop-hdfs-datanode
      - cmd: data_run_dir
      - cmd: dfs_data_dir
      - file: bigtop_java_home
{% if salt['pillar.get']('hdp2:security:enable', False) %}
      - file: /etc/default/hadoop-hdfs-datanode
      - cmd: generate_hadoop_keytabs
{% endif %}
    - watch:
      - file: /etc/hadoop/conf

##
# Starts the yarn nodemanager service
#
# Depends on: JDK7
##
hadoop-yarn-nodemanager-svc:
  cmd:
    - run
    - user: yarn
    - name: {{ yarn_script_dir }}/yarn-daemon.sh start nodemanager
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/yarn/yarn-yarn-nodemanager.pid'
    - require: 
      - pkg: hadoop-yarn-nodemanager
      - cmd: datanode_mapred_local_dirs
      - file: bigtop_java_home
{% if salt['pillar.get']('hdp2:security:enable', False) %}
      - file: /etc/default/hadoop-hdfs-datanode
      - cmd: generate_hadoop_keytabs
{% endif %}
    - watch:
      - file: /etc/hadoop/conf

##
# Starts the mapreduce service
#
# Depends on: JDK7
##
#hadoop-mapreduce-svc:
#  service:
#    - running
#    - name: hadoop-mapreduce
#    - require:
#      - pkg: hadoop-mapreduce
#      - cmd: datanode_mapred_local_dirs
#      - file: /etc/hadoop/conf
#    - watch:
#      - file: /etc/hadoop/conf

# make the local storage directories
datanode_mapred_local_dirs:
  cmd:
    - run
    - name: 'mkdir -p {{ mapred_local_dir }} && chmod -R 755 {{ mapred_local_dir }} && chown -R yarn:yarn {{ mapred_local_dir }}'
    - unless: "test -d {{ mapred_local_dir }} && [ `stat -c '%U' {{ mapred_local_dir }}` == 'yarn' ]"
    - require:
      - pkg: hadoop-yarn-nodemanager

# make the hdfs data directories
dfs_data_dir:
  cmd:
    - run
    - name: 'for dd in `echo {{ dfs_data_dir }} | sed "s/,/\n/g"`; do mkdir -p $dd && chmod -R 755 $dd && chown -R hdfs:hdfs $dd; done'
    - unless: "test -d `echo {{ dfs_data_dir }} | awk -F, '{print $1}'` && [ $(stat -c '%U' $(echo {{ dfs_data_dir }} | awk -F, '{print $1}')) == 'hdfs' ]"
    - require:
      - pkg: hadoop-hdfs-datanode

data_run_dir:
  cmd:
    - run
    - name: mkdir /var/run/hadoop-hdfs && chown hdfs:hadoop /var/run/hadoop-hdfs
    - unless: 'test -d /var/run/hadoop-hdfs'
    - require:
      - pkg: hadoop-hdfs-datanode


