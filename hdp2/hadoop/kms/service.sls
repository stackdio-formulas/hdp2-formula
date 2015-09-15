
mysqld:
  service:
    - running
    - require:
      - pkg: ranger-kms


configure-kms:
  cmd:
    - run
    - user: root
    - name: /usr/hdp/current/ranger-kms/setup.sh
    - env:
      - JAVA_HOME: /usr/java/latest
    - require:
      - service: mysqld


ranger-kms-svc:
  service:
    - running
    - name: ranger-kms
    - require:
      - pkg: ranger-kms
      - cmd: fix-kms-script
      - cmd: configure-kms
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hadoop_kms_keytabs
      {% endif %}
    - watch:
      - file: /etc/ranger/kms/conf
