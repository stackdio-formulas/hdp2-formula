{% set oozie_data_dir = '/var/lib/oozie' %}

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

extjs:
  cmd:
    - run
    - name: 'cp /usr/share/HDP-oozie/ext-2.2.zip /usr/lib/oozie/libext/'
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

