#
# Install the Oozie package
#

{% set oozie_host = salt['mine.get']('G@stack_id:' ~ grains.stack_id ~ ' and G@roles:hdp2.oozie', 'grains.items', 'compound').values()[0]['fqdn'] %}

include:
  - hdp2.repo
  {% if pillar.hdp2.security.enable %}
  - krb5
  - hdp2.security
  {% endif %}
  {% if pillar.hdp2.encryption.enable %}
  - hdp2.oozie.encryption
  {% endif %}

oozie-client:
  pkg:
    - installed
    - require:
      - cmd: repo_placeholder

{% if pillar.hdp2.encryption.enable %}
  {% set oozie_url = 'https://' ~ oozie_host ~ ':11443/oozie' %}
{% else %}
  {% set oozie_url = 'http://' ~ oozie_host ~ ':11000/oozie' %}
{% endif %}

/etc/profile.d/oozie.sh:
  file:
    - managed
    - user: root
    - group: root
    - mode: 644
    - contents:
      - export OOZIE_URL={{ oozie_url }}
      {% if pillar.hdp2.security.enable %}
      - export OOZIE_CLIENT_OPTS="-Djava.security.krb5.conf={{ pillar.krb5.conf_file }}"
      {% endif %}
      {% if pillar.hdp2.encryption.enable %}
      - export OOZIE_CLIENT_OPTS="${OOZIE_CLIENT_OPTS} -Djavax.net.ssl.trustStore=/etc/oozie/conf/oozie.truststore -Djavax.net.ssl.trustStorePassword=oozie123"
      {% endif %}
