repo_placeholder:
  cmd:
    - run
    - name: which java
    - cmd: hortonworks_repo

{% if grains['os_family'] == 'Debian' %}

# THIS MAY NOT WORK ON UBUNTU

# Hortonworks has 2 different apt repos that they put their distros in - we'll try both of them here to see which one works
hortonworks_repo_try1:
  cmd:
    - run
    - name: curl -o /etc/apt/sources.list.d/hdp.list http://public-repo-1.hortonworks.com/HDP/ubuntu12/2.x/GA/{{ pillar.hdp2.version }}/hdp.list
    - user: root
    - unless: 'apt-cache search | grep HDP'

hortonworks_repo:
  cmd:
    - run
    - name: curl -o /etc/apt/sources.list.d/hdp.list http://public-repo-1.hortonworks.com/HDP/ubuntu12/2.x/updates/{{ pillar.hdp2.version }}/hdp.list
    - user: root
    - unless: 'apt-cache search | grep HDP'
    - require:
      - cmd: hortonworks_repo_try1

{% elif grains['os_family'] == 'RedHat' %}

{% set releasever = grains.osmajorrelease %}

# Hortonworks has 2 different yum repos that they put their distros in - we'll try both of them here to see which one works
hortonworks_repo_try1:
  cmd:
    - run
    - name: curl -o /etc/yum.repos.d/hdp.repo http://public-repo-1.hortonworks.com/HDP/centos{{ releasever }}/2.x/GA/{{ pillar.hdp2.version }}/hdp.repo
    - unless: 'yum list | grep HDP'
    - user: root

hortonworks_repo:
  cmd:
    - run
    - name: curl -o /etc/yum.repos.d/hdp.repo http://public-repo-1.hortonworks.com/HDP/centos{{ releasever }}/2.x/updates/{{ pillar.hdp2.version }}/hdp.repo
    - user: root
    - unless: 'yum list | grep HDP'
    - require:
      - cmd: hortonworks_repo_try1

{% endif %}

