{% set mapred_local_dir = salt['pillar.get']('hdp2:mapred:local_dir', '/mnt/yarn') %}
{% set dfs_data_dir = salt['pillar.get']('hdp2:dfs:data_dir', '/mnt/hadoop/hdfs/data') %}


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
    - name: /usr/hdp/current/hadoop-hdfs-datanode/../hadoop/sbin/hadoop-daemon.sh start datanode
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/hdfs/hadoop-hdfs-datanode.pid'
    - require: 
      - pkg: hadoop-hdfs-datanode
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
    - name: /usr/hdp/current/hadoop-yarn-nodemanager/sbin/yarn-daemon.sh start nodemanager
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


