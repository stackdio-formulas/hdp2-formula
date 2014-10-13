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

{% if grains['os_family'] == 'Debian' %}
extend:
  remove_policy_file:
    file:
      - require:
        - service: zookeeper-server-svc
{% endif %}

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
  service:
    - running
    - name: zookeeper-server
    - unless: service zookeeper-server status
    - require:
        - cmd: zookeeper-init
        - file: /etc/zookeeper/conf/zookeeper-env.sh
        - file: /etc/zookeeper/conf/log4j.properties
{% if salt['pillar.get']('hdp2:security:enable', False) %}
        - cmd: generate_zookeeper_keytabs
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

{% if grains['os_family'] == 'RedHat' %}
zookeeper_group:
  group:
    - present
    - name: zookeeper
{% endif %}

zookeeper-init:
  cmd:
    - run
    - name: 'service zookeeper-server init --force'
    - unless: 'ls {{pillar.hdp2.zookeeper.data_dir}}/version-*'
    - require:
      - file: myid
      {% if grains['os_family'] == 'RedHat' %}
      - group: zookeeper
      {% endif %}

zk_data_dir:
  file:
    - directory
    - name: {{pillar.hdp2.zookeeper.data_dir}}
    - user: zookeeper
    - group: zookeeper
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
