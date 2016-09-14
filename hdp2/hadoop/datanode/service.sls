{% set yarn_local_dir = salt['pillar.get']('hdp2:yarn:local_dirs', '/mnt/hadoop/yarn/local') %}
{% set yarn_log_dir = salt['pillar.get']('hdp2:yarn:log_dirs', '/mnt/hadoop/yarn/logs') %}
{% set dfs_data_dir = salt['pillar.get']('hdp2:dfs:data_dir', '/mnt/hadoop/hdfs/dn') %}

# The scripts for starting services are in different places depending on the hdp version, so set them here
{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set hadoop_script_dir = '/usr/hdp/current/hadoop-hdfs-datanode/../hadoop/sbin' %}
{% set yarn_script_dir = '/usr/hdp/current/hadoop-yarn-nodemanager/sbin' %}
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

kill-datanode:
  cmd:
    - run
    {% if pillar.hdp2.security.enable %}
    - user: root
    {% else %}
    - user: hdfs
    {% endif %}
    - name: {{ hadoop_script_dir }}/hadoop-daemon.sh stop datanode
    - onlyif: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/hdfs/hadoop-hdfs-datanode.pid'
    - env:
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - require:
      - pkg: hadoop-hdfs-datanode

kill-nodemanager:
  cmd:
    - run
    - user: yarn
    - name: {{ yarn_script_dir }}/yarn-daemon.sh stop nodemanager
    - onlyif: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/yarn/yarn-yarn-nodemanager.pid'
    - env:
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - require:
      - pkg: hadoop-yarn-nodemanager

# make the local storage directories
datanode_yarn_local_dirs:
  cmd:
    - run
    - name: 'for dd in `echo {{ yarn_local_dir}} | sed "s/,/\n/g"`; do mkdir -p $dd && chmod -R 755 $dd && chown -R yarn:yarn `dirname $dd`; done'
    - unless: "test -d `echo {{ yarn_local_dir }} | awk -F, '{print $1}'` && [ $(stat -c '%U' $(echo {{ yarn_local_dir }} | awk -F, '{print $1}')) == 'yarn' ]"
    - require:
      - pkg: hadoop-yarn-nodemanager

# make the log storage directories
datanode_yarn_log_dirs:
  cmd:
    - run
    - name: 'for dd in `echo {{ yarn_log_dir}} | sed "s/,/\n/g"`; do mkdir -p $dd && chmod -R 755 $dd && chown -R yarn:yarn `dirname $dd`; done'
    - unless: "test -d `echo {{ yarn_log_dir }} | awk -F, '{print $1}'` && [ $(stat -c '%U' $(echo {{ yarn_log_dir }} | awk -F, '{print $1}')) == 'yarn' ]"
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

hadoop-hdfs-datanode-svc:
  cmd:
    - run
    {% if pillar.hdp2.security.enable %}
    - user: root
    {% else %}
    - user: hdfs
    {% endif %}
    - name: {{ hadoop_script_dir }}/hadoop-daemon.sh start datanode
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/hdfs/hadoop-hdfs-datanode.pid'
    - env:
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - require: 
      - pkg: hadoop-hdfs-datanode
      - cmd: kill-datanode
      - cmd: dfs_data_dir
      - file: bigtop_java_home
      {% if pillar.hdp2.encryption.enable %}
      - cmd: chown-keystore
      {% endif %}
      {% if pillar.hdp2.security.enable %}
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
    - env:
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - require: 
      - pkg: hadoop-yarn-nodemanager
      - cmd: datanode_yarn_local_dirs
      - cmd: datanode_yarn_log_dirs
      - file: bigtop_java_home
      - cmd: kill-nodemanager
      {% if pillar.hdp2.encryption.enable %}
      - cmd: chown-keystore
      {% endif %}
      {% if pillar.hdp2.security.enable %}
      - cmd: generate_hadoop_keytabs
      {% endif %}
    - watch:
      - file: /etc/hadoop/conf

