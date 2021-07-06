repo_placeholder:
  cmd:
    - run
    - name: which java
    - require:
      - pkgrepo: hortonworks_repo

{% if grains['os_family'] == 'Debian' %}

# THIS MAY NOT WORK ON UBUNTU


{% elif grains['os_family'] == 'RedHat' %}

{% set releasever = grains.osmajorrelease %}

hortonworks_repo:
  pkgrepo:
    - managed
    - humanname: "Hortonworks' Distribution for Hadoop, Version 2"
    - baseurl: "https://{{pillar.cdh5.manager.cloudera_user}}:{{pillar.cdh5.manager.cloudera_password}}@archive.cloudera.com/p/HDP/2.x/{{ pillar.hdp2.version }}/centos{{ releasever }}"
    - gpgkey: https://{{pillar.cdh5.manager.cloudera_user}}:{{pillar.cdh5.manager.cloudera_password}}@archive.cloudera.com/p/HDP/2.x/{{ pillar.hdp2.version }}/centos{{ releasever }}/RPM-GPG-KEY/RPM-GPG-KEY-Jenkins
    - gpgcheck: 1

{% endif %}

{% if grains['os'] == "RedHat" %}  # And not centos

rhel-optional:
  pkgrepo.managed:
    - name: rhui-REGION-rhel-server-optional

libtirpc-devel:
  pkg.installed

{% endif %}
