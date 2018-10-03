
# The scripts for starting services are in different places depending on the hdp version, so set them here
{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set hadoop_script_dir = '/usr/hdp/current/hadoop-hdfs-datanode/../hadoop/sbin' %}
{% else %}
{% set hadoop_script_dir = '/usr/lib/hadoop/sbin' %}
{% endif %}


##
# Starts the datanode service
#
# Depends on: JDK7
#
##

/var/run/hadoop-hdfs:
  file.directory:
    - user: hdfs
    - group: hadoop
    - mode: 755
    - require:
      - pkg: hadoop-hdfs-datanode

kill-datanode:
  cmd.run:
    {% if pillar.hdp2.security.enable %}
    - user: root
    {% else %}
    - user: hdfs
    {% endif %}
    - name: {{ hadoop_script_dir }}/hadoop-daemon.sh stop datanode
    - onlyif: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop-hdfs/hadoop-hdfs-datanode.pid'
    - env:
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - require:
      - pkg: hadoop-hdfs-datanode

# make the hdfs data directories
{% for data_dir in pillar.hdp2.dfs.data_dirs %}

dfs-data-dir-{{ data_dir }}:
  file.directory:
    - name: {{ data_dir }}
    - user: hdfs
    - group: hdfs
    - mode: 755
    - makedirs: true
    - require:
      - pkg: hadoop-hdfs-datanode
    - require_in:
      - cmd: hadoop-hdfs-datanode-svc

{% endfor %}

hadoop-hdfs-datanode-svc:
  cmd.run:
    {% if pillar.hdp2.security.enable %}
    - user: root
    {% else %}
    - user: hdfs
    {% endif %}
    - name: {{ hadoop_script_dir }}/hadoop-daemon.sh start datanode
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop-hdfs/hadoop-hdfs-datanode.pid'
    - env:
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - require: 
      - pkg: hadoop-hdfs-datanode
      - cmd: kill-datanode
      - file: bigtop_java_home
      - file: /var/run/hadoop-hdfs
      {% if pillar.hdp2.encryption.enable %}
      - cmd: chown-keystore
      {% endif %}
      {% if pillar.hdp2.security.enable %}
      - cmd: generate_hadoop_keytabs
      {% endif %}
    - watch:
      - file: /etc/hadoop/conf
