
# The scripts for starting services are in different places depending on the hdp version, so set them here
{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set hadoop_script_dir = '/usr/hdp/current/hadoop-yarn-resourcemanager/../hadoop/sbin' %}
{% set yarn_script_dir = '/usr/hdp/current/hadoop-yarn-resourcemanager/sbin' %}
{% else %}
{% set hadoop_script_dir = '/usr/lib/hadoop/sbin' %}
{% set yarn_script_dir = '/usr/lib/hadoop-yarn/sbin' %}
{% endif %}

##
# Starts the namenode service.
#
# Depends on: JDK7
##

kill-resourcemanager:
  cmd.run:
    - user: yarn
    - name: {{ yarn_script_dir }}/yarn-daemon.sh stop resourcemanager
    - onlyif: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop-yarn/yarn-yarn-resourcemanager.pid'
    - env:
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - require:
      - pkg: hadoop-yarn-resourcemanager

hadoop-yarn-resourcemanager-svc:
  cmd.run:
    - user: yarn
    - name: {{ yarn_script_dir }}/yarn-daemon.sh start resourcemanager
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop-yarn/yarn-yarn-resourcemanager.pid'
    - env:
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - require:
      - pkg: hadoop-yarn-resourcemanager
      - cmd: kill-resourcemanager
      - file: bigtop_java_home
      {% if pillar.hdp2.encryption.enable %}
      - cmd: chown-keystore
      {% endif %}
      {% if pillar.hdp2.security.enable %}
      - cmd: generate_hadoop_keytabs
      {% endif %}
    - watch:
      - file: /etc/hadoop/conf
