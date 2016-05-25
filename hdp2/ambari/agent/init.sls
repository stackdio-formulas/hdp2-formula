include:
  - hdp2.ambari.common

ambari-agent:
  pkg:
    - installed
    - require:
      - pkg: needed-pkgs

/etc/ambari-agent/conf/ambari-agent.ini:
  file:
    - managed
    - source: salt://hdp2/ambari/conf/ambari-agent.ini
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - require:
      - pkg: ambari-agent

ambari-agent-svc:
  service:
    - running
    - name: ambari-agent
    - watch:
      - file: /etc/ambari-agent/conf/ambari-agent.ini