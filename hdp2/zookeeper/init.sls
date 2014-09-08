#
# Install the ZooKeeper service
#
include:
  - hdp2.repo
{% if salt['pillar.get']('hdp2:zookeeper:start_service', True) %}
  - hdp2.zookeeper.service
{% endif %}
{% if salt['pillar.get']('hdp2:security:enable', False) %}
  - krb5
  - hdp2.security
  - hdp2.zookeeper.security
{% endif %}

zookeeper:
  pkg:
    - installed
    - require:
      - cmd: repo_placeholder

zookeeper-server:
  pkg:
    - installed
    - require:
      - pkg: zookeeper

/etc/zookeeper/conf/log4j.properties:
  file:
    - replace
    - pattern: 'maxbackupindex=20'
    - repl: 'maxbackupindex={{ pillar.hdp2.max_log_index }}'
    - require:
      - pkg: zookeeper-server


