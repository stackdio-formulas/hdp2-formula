repo_placeholder:
  cmd:
    - run
    - name: which java
    - require:
      - cmd: hortonworks_repo

{% if grains['os_family'] == 'Debian' %}

# THIS MAY NOT WORK ON UBUNTU


hortonworks_repo:
  cmd:
    - run
    - name: curl -o /etc/apt/sources.list.d/hdp.list http://public-repo-1.hortonworks.com/HDP/ubuntu12/2.x/updates/{{ pillar.hdp2.version }}/hdp.list
    - user: root
    - unless: 'apt-cache search | grep HDP'

{% elif grains['os_family'] == 'RedHat' %}

{% set releasever = grains.osmajorrelease %}

hdp_gpl:
  cmd:
    - run
    - name: curl -o /etc/yum.repos.d/hdp_gpl.repo https://{{pillar.cdh5.manager.cloudera_user}}:{{pillar.cdh5.manager.cloudera_password}}@archive.cloudera.com/p/HDP/2.x/{{ pillar.hdp2.version }}/centos{{ releasever }}/hdp.gpl.repo
    - user: root

hortonworks_repo:
  cmd:
    - run
    - name: curl -o /etc/yum.repos.d/hdp.repo https://{{pillar.cdh5.manager.cloudera_user}}:{{pillar.cdh5.manager.cloudera_password}}@archive.cloudera.com/p/HDP/2.x/{{ pillar.hdp2.version }}/centos{{ releasever }}/hdp.repo
    - user: root
    - require:
      - cmd: hdp_gpl

{% endif %}

{% if grains['os'] == "RedHat" %}  # And not centos

rhel-optional:
  pkgrepo.managed:
    - name: rhui-REGION-rhel-server-optional

libtirpc-devel:
  pkg.installed

{% endif %}
