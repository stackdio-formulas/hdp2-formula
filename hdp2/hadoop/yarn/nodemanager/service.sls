
# The scripts for starting services are in different places depending on the hdp version, so set them here
{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set hadoop_script_dir = '/usr/hdp/current/hadoop-yarn-nodemanager/../hadoop/sbin' %}
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
    - env:
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - onlyif: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop-yarn/yarn-yarn-nodemanager.pid'
    - require:
      - pkg: hadoop-yarn-nodemanager

# make the local storage directories
{% for local_dir in pillar.hdp2.yarn.local_dirs %}

yarn-local-dir-{{ local_dir }}:
  file:
    - directory
    - name: {{ local_dir }}
    - user: yarn
    - group: yarn
    - mode: 755
    - makedirs: true
    - require:
      - pkg: hadoop-yarn-nodemanager
    - require_in:
      - cmd: hadoop-yarn-nodemanager-svc

{% endfor %}

# make the log storage directories
{% for log_dir in pillar.hdp2.yarn.log_dirs %}

yarn-log-dir-{{ log_dir }}:
  file:
    - directory
    - name: {{ log_dir }}
    - user: yarn
    - group: yarn
    - mode: 755
    - makedirs: true
    - require:
      - pkg: hadoop-yarn-nodemanager
    - require_in:
      - cmd: hadoop-yarn-nodemanager-svc

{% endfor %}

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
    - env:
      - HADOOP_LIBEXEC_DIR: '{{ hadoop_script_dir }}/../libexec'
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop-yarn/yarn-yarn-nodemanager.pid'
    - require: 
      - pkg: hadoop-yarn-nodemanager
      - file: /etc/hadoop/conf
      - file: bigtop_java_home
      - cmd: kill-nodemanager
      {% if pillar.hdp2.encryption.enable %}
      - cmd: chown-keystore
      {% endif %}
      {% if pillar.hdp2.security.enable %}
      - cmd: generate_hadoop_keytabs
      {% endif %}
