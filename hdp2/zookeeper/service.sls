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
    - user: root
    - group: root
    - mode: 644
    - require: 
      - pkg: zookeeper

/etc/zookeeper/conf/zookeeper-env.sh:
  file:
    - managed
    - template: jinja
    - source: salt://hdp2/etc/zookeeper/conf/zookeeper-env.sh
    - user: root
    - group: root
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
    - require_in:
      - cmd: zookeeper-server-svc

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
    - require_in:
      - cmd: zookeeper-server-svc
{% endif %}

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
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_zookeeper_keytabs
      {% endif %}

myid:
  file:
    - managed
    - name: '{{pillar.hdp2.zookeeper.data_dir}}/myid'
    - template: jinja
    - user: zookeeper
    - group: hadoop
    - mode: 644
    - source: salt://hdp2/etc/zookeeper/conf/myid
    - require:
      - file: zk_data_dir

zookeeper-server-svc:
  cmd:
    - run
    - user: zookeeper
    - name: export ZOOCFGDIR=/etc/zookeeper/conf; source /etc/zookeeper/conf/zookeeper-env.sh; {{ zk_script_dir }}/zkServer.sh start
    - unless: '. /etc/init.d/functions && pidofproc -p {{pillar.hdp2.zookeeper.data_dir}}/zookeeper_server.pid'
    - require:
        - file: /etc/zookeeper/conf/zookeeper-env.sh
        - file: /etc/zookeeper/conf/log4j.properties
        - file: /etc/zookeeper/conf/zoo.cfg
        - file: bigtop_java_home_zoo
{% if salt['pillar.get']('hdp2:security:enable', False) %}
        - cmd: generate_zookeeper_keytabs
{% endif %}
    - watch:
        - file: /etc/zookeeper/conf/zookeeper-env.sh
        - file: /etc/zookeeper/conf/log4j.properties
        - file: /etc/zookeeper/conf/zoo.cfg

