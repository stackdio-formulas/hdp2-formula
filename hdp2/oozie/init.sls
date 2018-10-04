{% set oozie_data_dir = '/var/lib/oozie' %}

# The scripts for starting services are in different places depending on the hdp version, so set them here
{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set oozie_home = '/usr/hdp/current/oozie-client' %}
{% set lzo_pkg = 'hadooplzo' %}
{% else %}
{% set oozie_home = '/usr/lib/oozie' %}
{% set lzo_pkg = 'hadoop-lzo' %}
{% endif %}

#
# Install the Oozie package
#

include:
  - hdp2.repo
  - hdp2.landing_page
  - hdp2.hadoop.conf
  {% if salt['pillar.get']('hdp2:oozie:start_service', True) %}
  - hdp2.oozie.service
  {% endif %}
  {% if pillar.hdp2.encryption.enable %}
  - hdp2.oozie.encryption
  {% endif %}
  {% if pillar.hdp2.security.enable %}
  - krb5
  - hdp2.security
  - hdp2.oozie.security
  {% endif %}



oozie:
  pkg:
    - installed
    - pkgs:
      - oozie
      - oozie-client
      - {{ lzo_pkg }}
      - hadoop-hdfs
      - hadoop-yarn
      - hadoop-mapreduce
      # oozie scripts depend on zip AND unzip, but don't list them as deps :/
      - zip
      - unzip
    - require:
      - cmd: repo_placeholder
    {% if pillar.hdp2.encryption.enable %}
    - require_in:
      - file: /etc/oozie/conf/ca.crt
    {% endif %}

/etc/oozie/conf/hadoop-conf:
  file:
    - symlink
    - target: /etc/hadoop/conf
    - force: true
    - user: root
    - group: root
    - require:
      - file: /etc/hadoop/conf
      - pkg: oozie

/etc/oozie/conf/oozie-log4j.properties:
  file:
    - replace
    - pattern: 'RollingPolicy.MaxHistory=720'
    - repl: 'RollingPolicy.MaxHistory={{ salt['pillar.get']('hdp2:oozie:max_log_index', 168) }}'
    - require:
      - pkg: oozie

{% if pillar.hdp2.security.enable %}
/etc/oozie/conf/oozie-site.xml:
  file:
    - managed
    - source: salt://hdp2/etc/oozie/conf/oozie-site.xml
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - require:
      - pkg: oozie
{% endif %}

/etc/oozie/conf/oozie-env.sh:
  file:
    - managed
    - source: salt://hdp2/etc/oozie/conf/oozie-env.sh
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - require:
      - pkg: oozie

download_extjs:
  cmd.run:
    - name: curl -o /tmp/ext-2.2.zip http://archive.cloudera.com/gplextras/misc/ext-2.2.zip
    - user: root

extjs:
  cmd:
    - run
    - name: 'cp /tmp/ext-2.2.zip {{ oozie_home }}/libext/'
    - user: root
    - require:
      - cmd: download_extjs
      - pkg: oozie
      - cmd: hadoop-lzo

hadoop-lzo:
  cmd:
    - run
    - name: 'cp {{ oozie_home }}/../hadoop/lib/hadoop-lzo*.jar {{ oozie_home }}/libext/'
    - user: root
    - require:
      - pkg: oozie

# add all the hbase jars
{% set hbase_jar_list = ['hbase-client', 'hbase-common', 'hbase-hadoop2-compat', 'hbase-protocol', 'hbase-server'] %}

{% for hbase_jar in hbase_jar_list %}
{{ hbase_jar }}-jar:
  file.symlink:
    - name: /usr/hdp/current/oozie-server/libext/{{ hbase_jar }}.jar
    - target: /usr/hdp/current/hbase-client/lib/{{ hbase_jar }}.jar
    - user: root
    - group: root
    - require:
      - pkg: oozie
    - require_in:
      - file: /var/log/oozie
{% endfor %}

/var/log/oozie:
  file:
    - directory
    - user: oozie
    - group: oozie
    - recurse:
      - user
      - group
    - require:
      - pkg: oozie

/var/lib/oozie:
  file:
    - directory
    - user: oozie
    - group: oozie
    - recurse:
      - user
      - group
    - require:
      - pkg: oozie
