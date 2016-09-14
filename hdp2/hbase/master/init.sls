# 
# Install the HBase master package
#
include:
  - hdp2.repo
  - hdp2.hadoop.client
  - hdp2.hbase.conf
{% if salt['pillar.get']('hdp2:hbase:manage_zk', True) %}
  - hdp2.zookeeper
{% endif %}
{% if salt['pillar.get']('hdp2:hbase:start_service', True) %}
  - hdp2.hbase.master.service
{% endif %}
{% if pillar.hdp2.security.enable %}
  - krb5
  - hdp2.security
  - hdp2.hbase.security
{% endif %}

hbase-master:
  pkg:
    - installed 
    - pkgs:
      - hbase-master
      - hbase-thrift
    - require:
      - cmd: repo_placeholder
{% if pillar.hdp2.security.enable %}
      - file: krb5_conf_file
{% endif %}
{% if salt['pillar.get']('hdp2:hbase:manage_zk', True) %}
      - cmd: zookeeper-server-svc
{% endif %}
    - require_in:
      - file: {{ pillar.hdp2.hbase.log_dir }}
      - file: {{ pillar.hdp2.hbase.tmp_dir }}
      - file: /etc/hbase/conf/hbase-env.sh
      - file: /etc/hbase/conf/hbase-site.xml
