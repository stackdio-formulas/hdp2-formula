
{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set kms_script_dir = '/usr/hdp/current/hadoop-kms-server/sbin' %}
{% else %}
{% set kms_script_dir = '/usr/lib/hadoop-kms/sbin' %}
{% endif %}


hadoop-kms-server-svc:
  cmd:
    - run
    - name: {{ kms_script_dir }}/kms.sh run
    - require:
      - pkg: hadoop-kms-server
      - file: /etc/hadoop-kms/conf
      - unless: '. /etc/init.d/functions && pidofproc -p /var/run/hadoop/kms/hadoop-kms-server.pid'
      {% if salt['pillar.get']('hdp2:security:enable', False) %}
      - cmd: generate_hadoop_kms_keytabs
      {% endif %}
    - watch:
      - file: /etc/hadoop-kms/conf
