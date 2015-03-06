{%- set standby = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:hdp2.hadoop.standby', 'grains.items', 'compound') -%}


# The scripts for starting services are in different places depending on the hdp version, so set them here
{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set hadoop_script_dir = '/usr/hdp/current/hadoop-client/sbin' %}
{% set zk_script_dir = '/usr/hdp/current/zookeeper-client/bin' %}
{% else %}
{% set hadoop_script_dir = '/usr/lib/hadoop/sbin' %}
{% set zk_script_dir = '/usr/lib/zookeeper/bin' %}
{% endif %}

#
# Start the ZooKeeper service
#
include:
  - hdp2.repo

bigtop_java_home_zoo:
  file:
    - managed
    - name: /usr/lib/bigtop-utils/bigtop-detect-javahome
    - makedirs: true
    - contents: 'export JAVA_HOME=/usr/java/latest'
    - user: root
    - group: root
    - require:
      - pkg: zookeeper

/etc/zookeeper/conf/zoo.cfg:
  file:
    - managed
    - template: jinja
    - source: salt://hdp2/etc/zookeeper/conf/zoo.cfg
    - mode: 755
    - require: 
      - pkg: zookeeper

/etc/zookeeper/conf/zookeeper-env.sh:
  file:
    - managed
    - template: jinja
    - source: salt://hdp2/etc/zookeeper/conf/zookeeper-env.sh
    - mode: 644
    - require:
      - file: /etc/zookeeper/conf/zoo.cfg

{% if salt['pillar.get']('hdp2:security:enable', False) %}
/etc/zookeeper/conf/jaas.conf:
  file:
    - managed
    - template: jinja
    - source: salt://hdp2/etc/zookeeper/conf/jaas.conf
    - user: root
    - group: root
    - mode: 644
    - require: 
      - pkg: zookeeper
      - file: /etc/zookeeper/conf/zookeeper-env.sh

/etc/zookeeper/conf/java.env:
  file:
    - managed
    - template: jinja
    - source: salt://hdp2/etc/zookeeper/conf/java.env
    - user: root
    - group: root
    - mode: 644
    - require: 
      - pkg: zookeeper
      - file: /etc/zookeeper/conf/zookeeper-env.sh
{% endif %}
    
zookeeper-server-svc:
  cmd:
    - run
    - user: zookeeper
    - name: export ZOOCFGDIR=/etc/zookeeper/conf; source /etc/zookeeper/conf/zookeeper-env.sh; {{ zk_script_dir }}/zkServer.sh start
    - unless: '. /etc/init.d/functions && pidofproc -p {{pillar.hdp2.zookeeper.data_dir}}/zookeeper_server.pid'
    - require:
        - file: /etc/zookeeper/conf/zookeeper-env.sh
        - file: /etc/zookeeper/conf/log4j.properties
{% if salt['pillar.get']('hdp2:security:enable', False) %}
        - cmd: generate_zookeeper_keytabs
{% endif %}

{% if standby %}
zkfc-svc:
  cmd:
    - run
    - user: zookeeper
    - name: {{ hadoop_script_dir }}/hadoop-daemon.sh start zkfc
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/zookeeper/hadoop-zookeeper-zkfc.pid'
    - require:
        - cmd: zookeeper-server-svc
        - cmd: zkfc_log_dir
        - cmd: zkfc_run_dir
{% endif %}

myid:
  file:
    - managed
    - name: '{{pillar.hdp2.zookeeper.data_dir}}/myid'
    - template: jinja
    - user: zookeeper
    - group: zookeeper
    - mode: 755
    - source: salt://hdp2/etc/zookeeper/conf/myid
    - require:
      - file: zk_data_dir

zkfc_log_dir:
  cmd:
    - run
    - name: 'mkdir -p /var/log/hadoop/zookeeper && chown zookeeper:hadoop /var/log/hadoop/zookeeper'
    - require:
      - file: myid

zkfc_run_dir:
  cmd:
    - run
    - name: 'mkdir -p /var/run/hadoop/zookeeper && chown zookeeper:hadoop /var/run/hadoop/zookeeper'
    - require:
      - file: myid

zk_data_dir:
  file:
    - directory
    - name: {{pillar.hdp2.zookeeper.data_dir}}
    - user: zookeeper
    - group: hadoop
    - dir_mode: 755
    - makedirs: true
    - require:
      - pkg: zookeeper-server
      {% if grains['os_family'] == 'RedHat' %}
      - group: zookeeper
      {% endif %}
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_zookeeper_keytabs
      {% endif %}
