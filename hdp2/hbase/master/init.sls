# 
# Install the HBase master package
#
include:
  - hdp2.repo
  - hdp2.hadoop.client
  - hdp2.zookeeper
  - hdp2.hbase.conf
{% if salt['pillar.get']('hdp2:hbase:start_service', True) %}
  - hdp2.hbase.master.service
{% endif %}
{% if salt['pillar.get']('hdp2:security:enable', False) %}
  - krb5
  - hdp2.security
  - hdp2.hbase.security
{% endif %}

extend:
  /etc/hbase/conf/hbase-site.xml:
    file:
      - require:
        - pkg: hbase-master
  /etc/hbase/conf/hbase-env.sh:
    file:
      - require:
        - pkg: hbase-master
  {{ pillar.hdp2.hbase.tmp_dir }}:
    file:
      - require:
        - pkg: hbase-master
  {{ pillar.hdp2.hbase.log_dir }}:
    file:
      - require:
        - pkg: hbase-master
{% if salt['pillar.get']('hdp2:security:enable', False) %}
  load_admin_keytab:
    module:
      - require:
        - file: /etc/krb5.conf
        - file: /etc/hbase/conf/hbase-site.xml
        - file: /etc/hbase/conf/hbase-env.sh
        - pkg: hbase-master
{% endif %}

hbase-master:
  pkg:
    - installed 
    - pkgs:
      - hbase-master
      - hbase-thrift
    - require:
      - cmd: repo_placeholder
{% if salt['pillar.get']('hdp2:security:enable', False) %}
      - file: /etc/krb5.conf
{% endif %}
