


ranger-kms-svc:
  service:
    - running
    - name: ranger-kms
    - require:
      - pkg: ranger-kms
      - file: /etc/init.d/ranger-kms
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hadoop_kms_keytabs
      {% endif %}
    - watch:
      - file: /etc/ranger/kms/conf
