# 
# Install the HBase regionserver package
#
include:
  - hdp2.repo
  - hdp2.landing_page
  - hdp2.hbase.conf
{% if salt['pillar.get']('hdp2:hbase:start_service', True) %}
  - hdp2.hbase.regionserver.service
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
        - pkg: hbase-regionserver
  /etc/hbase/conf/hbase-env.sh:
    file:
      - require:
        - pkg: hbase-regionserver
  {{ pillar.hdp2.hbase.tmp_dir }}:
    file:
      - require:
        - pkg: hbase-regionserver
  {{ pillar.hdp2.hbase.log_dir }}:
    file:
      - require:
        - pkg: hbase-regionserver
{% if salt['pillar.get']('hdp2:security:enable', False) %}
  load_admin_keytab:
    module:
      - require:
        - file: /etc/krb5.conf
        - file: /etc/hbase/conf/hbase-site.xml
        - file: /etc/hbase/conf/hbase-env.sh
        - pkg: hbase-regionserver
{% endif %}

hbase-regionserver:
  pkg:
    - installed 
    - require:
      - cmd: repo_placeholder
{% if salt['pillar.get']('hdp2:security:enable', False) %}
      - file: /etc/krb5.conf
{% endif %}
