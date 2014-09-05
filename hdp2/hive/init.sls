# 
# Install the Hive package
#
include:
  - hdp2.repo
  - hdp2.hive.conf
{% if salt['pillar.get']('hdp2:hive:start_service', True) %}
  - hdp2.hive.service
{% endif %}
{% if salt['pillar.get']('hdp2:security:enable', False) %}
  - krb5
  - hdp2.security
  - hdp2.hive.security
{% endif %}

extend:
  /etc/hive/conf/hive-site.xml:
    file:
      - require:
        - pkg: hive

hive:
  pkg:
    - installed
    - pkgs:
      - hive
      - hive-metastore
      - hive-server2
    - require:
      - pkg: mysql
      - cmd: repo_placeholder

# @todo move this out to its own formula
mysql:
  pkg:
    - installed
    - pkgs:
      - mysql-server
      {% if grains['os_family'] == 'Debian' %}
      - libmysql-java
      {% elif grains['os_family'] == 'RedHat' %}
      - mysql-connector-java
      {% endif %}

/usr/lib/hive/lib/mysql-connector-java.jar:
  file:
    - symlink
    - target: /usr/share/java/mysql-connector-java.jar
    - require: 
      - pkg: mysql

{% if 'hdp2.sentry' in grains.roles %}
add_sentry_jars:
  cmd:
    - run
    - name: "find /usr/lib/sentry/lib -type f -name 'sentry*.jar' | xargs -n1 -Ifile ln -s file ."
    - unless: 'ls sentry*.jar &> /dev/null'
    - cwd: /usr/lib/hive/lib
    - require:
      - pkg: hive

add_hive_jars_to_sentry:
  cmd:
    - run
    - name: "find /usr/lib/hive/lib -type f -name 'hive*.jar' | xargs -n1 -Ifile ln -s file ."
    - unless: 'ls hive*.jar &> /dev/null'
    - cwd: /usr/lib/sentry/lib
    - require:
      - pkg: hive
{% endif %}
