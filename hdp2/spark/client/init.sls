
include:
  - hdp2.repo
  - hdp2.landing_page

spark:
  pkg.installed:
    - require:
      - cmd: repo_placeholder

/etc/spark/conf/spark-defaults.conf:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - source: salt://hdp2/etc/spark/spark-defaults.conf
    - template: jinja
    - require:
      - pkg: spark

{% if pillar.hdp2.security.enable %}
/etc/spark/conf/spark-env.sh:
  file.append:
    - text:
      - SPARK_SUBMIT_OPTS="$SPARK_SUBMIT_OPTS -Djava.security.krb5.conf={{ pillar.krb5.conf_file }}"
    - require:
      - pkg: spark
{% endif %}
