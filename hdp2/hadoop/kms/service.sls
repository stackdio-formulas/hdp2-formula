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
      - file: /usr/hdp/current/ranger-kms/install.properties
      {% if pillar.hdp2.security.enable %}
      - cmd: generate_http_keytab
      - cmd: generate_hadoop_kms_keytabs
      {% endif %}

/etc/ranger/admin/conf:
  file:
    - recurse
    - source: salt://hdp2/etc/ranger/admin/conf
    - template: jinja
    - user: root
    - group: root
    - file_mode: 644
    - exclude_pat: '.*.swp'
    - require:
      - cmd: configure-ranger

reload-systemd-admin:
  cmd:
    - run
    - user: root
    - name: systemctl daemon-reload
    - require:
      - cmd: configure-ranger

ranger-admin-svc:
  service:
    - running
    - name: ranger-admin
    - init_delay: 10
    - require:
      - file: /usr/hdp/current/ranger-admin/install.properties
      - pkg: ranger-kms
      - cmd: configure-ranger
      - cmd: reload-systemd-admin
      - file: /etc/ranger/admin/conf
      {% if pillar.hdp2.security.enable %}
      - cmd: generate_http_keytab
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
      {% if pillar.hdp2.security.enable %}
      - cmd: generate_http_keytab
      - cmd: generate_hadoop_kms_keytabs
      {% endif %}

/etc/ranger/kms/conf:
  file:
    - recurse
    - source: salt://hdp2/etc/ranger/kms/conf
    - template: jinja
    - user: root
    - group: root
    - file_mode: 644
    - exclude_pat: '.*.swp'
    - require:
      - cmd: configure-ranger-kms

reload-systemd-kms:
  cmd:
    - run
    - user: root
    - name: systemctl daemon-reload
    - require:
      - cmd: configure-ranger-kms

ranger-kms-svc:
  service:
    - running
    - name: ranger-kms
    - require:
      - file: /usr/hdp/current/ranger-kms/install.properties
      - file: /etc/ranger/kms/conf/core-site.xml
      - pkg: ranger-kms
      - service: ranger-admin-svc
      - cmd: configure-ranger-kms
      - cmd: reload-systemd-kms
      - file: /etc/ranger/kms/conf
      {% if pillar.hdp2.security.enable %}
      - cmd: generate_http_keytab
      - cmd: generate_hadoop_kms_keytabs
      {% endif %}