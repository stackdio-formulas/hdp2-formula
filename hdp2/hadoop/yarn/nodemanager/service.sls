{% set yarn_local_dir = salt['pillar.get']('hdp2:yarn:local_dirs', '/mnt/hadoop/yarn/local') %}
{% set yarn_log_dir = salt['pillar.get']('hdp2:yarn:log_dirs', '/mnt/hadoop/yarn/logs') %}

# The scripts for starting services are in different places depending on the hdp version, so set them here
{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set hadoop_script_dir = '/usr/hdp/current/hadoop-hdfs-datanode/../hadoop/sbin' %}
{% set yarn_script_dir = '/usr/hdp/current/hadoop-yarn-nodemanager/sbin' %}
{% else %}
{% set hadoop_script_dir = '/usr/lib/hadoop/sbin' %}
{% set yarn_script_dir = '/usr/lib/hadoop-yarn/sbin' %}
{% endif %}

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
yarn_local_dirs:
  cmd:
    - run
    - name: 'for dd in `echo {{ yarn_local_dir}} | sed "s/,/\n/g"`; do mkdir -p $dd && chmod -R 755 $dd && chown -R yarn:yarn `dirname $dd`; done'
    - unless: "test -d `echo {{ yarn_local_dir }} | awk -F, '{print $1}'` && [ $(stat -c '%U' $(echo {{ yarn_local_dir }} | awk -F, '{print $1}')) == 'yarn' ]"
    - require:
      - pkg: hadoop-yarn-nodemanager

# make the log storage directories
yarn_log_dirs:
  cmd:
    - run
    - name: 'for dd in `echo {{ yarn_log_dir}} | sed "s/,/\n/g"`; do mkdir -p $dd && chmod -R 755 $dd && chown -R yarn:yarn `dirname $dd`; done'
    - unless: "test -d `echo {{ yarn_log_dir }} | awk -F, '{print $1}'` && [ $(stat -c '%U' $(echo {{ yarn_log_dir }} | awk -F, '{print $1}')) == 'yarn' ]"
    - require:
      - pkg: hadoop-yarn-nodemanager

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
      - cmd: yarn_local_dirs
      - cmd: yarn_log_dirs
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

