
# The scripts for starting services are in different places depending on the hdp version, so set them here
{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set hive_home = '/usr/hdp/current/hive-metastore' %}
{% else %}
{% set hive_home = '/usr/lib/hive' %}
{% endif %}

# 
# Start the Hive service
#

include:
  - hdp2.repo


# @todo move this out to its own formula
mysql-svc:
  service:
    - running
    {% if grains['os_family'] == 'Debian' %}
    - name: mysql
    {% elif grains['os_family'] == 'RedHat' %}
    - name: mysqld
    {% endif %}
    - require:
      - pkg: mysql

configure_metastore:
  cmd:
    - script
    - template: jinja
    - source: salt://hdp2/hive/configure_metastore.sh
    - unless: echo "show databases" | mysql -u root | grep metastore
    - require:
      - pkg: hive
      - service: mysql-svc
      - file: {{ hive_home }}/lib/mysql-connector-java.jar

create_warehouse_dir:
  cmd:
    - run
    - name: 'hdfs dfs -mkdir -p /user/{{pillar.hdp2.hive.user}}/warehouse'
    - user: hdfs
    - group: hdfs
    - require:
      - pkg: hive
{% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hive_keytabs 
{% endif %}

warehouse_dir_owner:
  cmd:
    - run
    - name: 'hdfs dfs -chown -R {{pillar.hdp2.hive.user}}:{{pillar.hdp2.hive.user}} /user/{{pillar.hdp2.hive.user}}'
    - user: hdfs
    - group: hdfs
    - require:
      - cmd: create_warehouse_dir

warehouse_dir_permissions:
  cmd:
    - run
    {% if salt['pillar.get']('hdp2:security:enable', False) %}
    - name: 'hdfs dfs -chmod 771 /user/{{pillar.hdp2.hive.user}}/warehouse'
    {% else %}
    - name: 'hdfs dfs -chmod 1777 /user/{{pillar.hdp2.hive.user}}/warehouse'
    {% endif %}
    - user: hdfs
    - group: hdfs
    - require:
      - cmd: warehouse_dir_owner

{{ hive_home }}/bin/hive-daemon.sh:
  file:
    - managed
    - template: jinja
    - source: salt://hdp2/hive/hive-daemon.sh
    - user: root
    - group: root
    - mode: 755
    - require:
      - pkg: hive

/etc/profile.d/hive.sh:
  file:
    - managed
    - user: root
    - group: root
    - mode: 644
    - contents: 'export HIVE_HOME={{ hive_home }} ; export HIVE_BIN=$HIVE_HOME/bin ; export HIVE_CONF_DIR=$HIVE_HOME/conf'

hive-metastore:
  cmd:
    - run
    - user: hive
    - name: '{{ hive_home }}/bin/hive-daemon.sh start hive-metastore'
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hive/hive-metastore.pid'
    - require:
      - file: {{ hive_home }}/bin/hive-daemon.sh
      - pkg: hive
      - cmd: configure_metastore
      - cmd: warehouse_dir_permissions
      - service: mysql-svc
      - file: {{ hive_home }}/lib/mysql-connector-java.jar
      - file: /etc/hive/conf/hive-site.xml
      - file: /mnt/tmp/
    - watch:
      - file: /etc/hive/conf/hive-site.xml

hive-server2:
  cmd:
    - run
    - user: hive
    - name: '{{ hive_home }}/bin/hive-daemon.sh start hive-server2'
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hive/hive-server2.pid'
    - require: 
      - cmd: hive-metastore
{% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hive_keytabs 
{% endif %}
    - watch:
      - file: /etc/hive/conf/hive-site.xml

/mnt/tmp/:
  file:
    - directory
    - user: root
    - group: root
    - dir_mode: 777
    - recurse:
      - mode
