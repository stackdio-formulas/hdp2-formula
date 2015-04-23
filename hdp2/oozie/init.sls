{% set oozie_data_dir = '/var/lib/oozie' %}

# The scripts for starting services are in different places depending on the hdp version, so set them here
{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set oozie_home = '/usr/hdp/current/oozie-client' %}
{% else %}
{% set oozie_home = '/usr/lib/oozie' %}
{% endif %}

# 
# Install the Oozie package
#

include:
  - hdp2.repo
  - hdp2.landing_page
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
      - hadooplzo
      # oozie scripts depend on zip AND unzip, but don't list them as deps :/
      - zip
      - unzip
    - require:
      - cmd: repo_placeholder

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

/var/log/oozie:
  file:
    - directory
    - user: oozie
    - group: oozie
    - mode: 777
    - recurse:
      - user
      - group
    - require:
      - pkg: oozie
