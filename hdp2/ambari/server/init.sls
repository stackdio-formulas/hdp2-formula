include:
  - hdp2.ambari.common

ambari-server:
  pkg:
    - installed
    - require:
      - needed-pkgs

setup-ambari:
  cmd:
    - run
    - name: ambari-server setup --silent
    - require:
      - pkg: ambari-server

ambari-server-svc:
  service:
    - running
    - name: ambari-server
    - require:
      - cmd: setup-ambari
