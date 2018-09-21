#
# Install the HBase client package
#
include:
  - hdp2.repo
  - hdp2.hadoop.client
  - hdp2.hbase.conf
  - hdp2.landing_page
  {% if pillar.hdp2.encryption.enable %}
  - hdp2.hbase.encryption
  {% endif %}
  {% if pillar.hdp2.security.enable %}
  - hdp2.hbase.security
  {% endif %}

hbase:
pkg.installed:
  - require:
    - module: hdp2_refresh_db
    {% if pillar.hdp2.security.enable %}
    - file: krb5_conf_file
    {% endif %}
  - require_in:
    - file: {{ pillar.hdp2.hbase.log_dir }}
    - file: {{ pillar.hdp2.hbase.tmp_dir }}
    - file: /etc/hbase/conf/hbase-env.sh
    - file: /etc/hbase/conf/hbase-site.xml
