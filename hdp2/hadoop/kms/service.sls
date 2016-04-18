
mysqld:
  service:
    - running
    {% if grains.os_family == 'RedHat' and grains.osmajorrelease == '7' %}
    - name: mariadb
    {% else %}
    - name: mysql
    {% endif %}
    - require:
      - pkg: ranger-kms

setup_mysql:
  cmd:
    - script
    - template: jinja
    - source: salt://hdp2/hadoop/kms/ranger_mysql.sh
    - require:
      - service: mysqld

/usr/hdp/current/ranger-admin/install.properties:
  file:
    - managed
    - template: jinja
    - source: salt://hdp2/hadoop/kms/install.properties-admin
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: ranger-kms


/usr/hdp/current/ranger-kms/install.properties:
  file:
    - managed
    - template: jinja
    - source: salt://hdp2/hadoop/kms/install.properties-kms
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: ranger-kms


configure-ranger:
  cmd:
    - run
    - user: root
    - name: /usr/hdp/current/ranger-admin/setup.sh
    - cwd: /usr/hdp/current/ranger-admin
    - env:
      - JAVA_HOME: /usr/java/latest
    - require:
      - service: mysqld
      - cmd: setup_mysql
      - file: /usr/hdp/current/ranger-admin/install.properties

ranger-admin-svc:
  service:
    - running
    - name: ranger-admin
    - init_delay: 10
    - require:
      - file: /usr/hdp/current/ranger-admin/install.properties
      - pkg: ranger-kms
      - cmd: configure-ranger
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hadoop_kms_keytabs
      {% endif %}

configure-ranger-kms:
  cmd:
    - run
    - user: root
    - name: /usr/hdp/current/ranger-kms/setup.sh
    - cwd: /usr/hdp/current/ranger-kms
    - env:
      - JAVA_HOME: /usr/java/latest
    - require:
      - service: mysqld
      - service: ranger-admin-svc
      - cmd: setup_mysql
      - file: /usr/hdp/current/ranger-kms/install.properties
      - cmd: configure-ranger

ranger-kms-svc:
  service:
    - running
    - name: ranger-kms
    - watch:
      - file: /usr/hdp/current/ranger-kms/install.properties
      - file: /etc/ranger/kms/conf/core-site.xml
    - require:
      - pkg: ranger-kms
      - service: ranger-admin-svc
      - cmd: configure-ranger-kms
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hadoop_kms_keytabs
      {% endif %}