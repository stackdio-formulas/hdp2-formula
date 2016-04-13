{% set oozie_data_dir = '/var/lib/oozie' %}
{% set kms = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:hdp2.hadoop.kms', 'grains.items', 'compound') %}

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
{% if salt['pillar.get']('hdp2:security:enable', False) %}
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
      - extjs
      - {{ lzo_pkg }}
      # oozie scripts depend on zip AND unzip, but don't list them as deps :/
      - zip
      - unzip
    - require:
      - cmd: repo_placeholder

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

{% if salt['pillar.get']('hdp2:security:enable', False) %}
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

extjs:
  cmd:
    - run
    - name: 'cp /usr/share/HDP-oozie/ext-2.2.zip {{ oozie_home }}/libext/'
    - user: root
    - require:
      - pkg: oozie
      - cmd: hadoop-lzo

hadoop-lzo:
  cmd:
    - run
    - name: 'cp {{ oozie_home }}/../hadoop/lib/hadoop-lzo*.jar {{ oozie_home }}/libext/'
    - user: root
    - require:
      - pkg: oozie

{% if kms %}
copy-keystore:
  cmd:
    - run
    - user: root
    - name: 'cp /etc/hadoop/conf/hadoop.keystore /etc/oozie/conf/oozie.keystore'
    - require:
      - pkg: oozie

chown-keystore:
  cmd:
    - run
    - user: root
    - name: 'chown oozie:oozie /etc/oozie/conf/oozie.keystore && chmod 440 /etc/oozie/conf/oozie.keystore'
    - require:
      - cmd: copy-keystore

enable-https:
  cmd:
    - run
    - user: root
    - name: alternatives --set oozie-tomcat-deployment /etc/oozie/tomcat-conf.https
    - require:
      - pkg: oozie
      - cmd: chown-keystore
    - require_in:
      - cmd: ooziedb
{% endif %}

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
