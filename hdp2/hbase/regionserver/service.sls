{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set hbase_script_dir = '/usr/hdp/current/hbase-regionserver/bin' %}
{% else %}
{% set hbase_script_dir = '/usr/lib/hbase/bin' %}
{% endif %}

#
# Install the HBase regionserver package
#

hbase-regionserver-svc:
  cmd:
    - run
    - user: hbase
    - name: {{ hbase_script_dir }}/hbase-daemon.sh start regionserver
    - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hbase/hbase-hbase-regionserver.pid'
    - require: 
      - pkg: hbase-regionserver
      - file: /etc/hbase/conf/hbase-site.xml
      - file: /etc/hbase/conf/hbase-env.sh
      - file: {{ pillar.hdp2.hbase.tmp_dir }}
      - file: {{ pillar.hdp2.hbase.log_dir }}
{% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hbase_keytabs
{% endif %}
    - watch:
      - file: /etc/hbase/conf/hbase-site.xml
      - file: /etc/hbase/conf/hbase-env.sh
