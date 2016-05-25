{% set releasever = grains.osmajorrelease %}

{% if grains['os_family'] == 'Debian' %}

# THIS MAY NOT WORK ON UBUNTU

# Hortonworks has 2 different apt repos that they put their distros in - we'll try both of them here to see which one works
ambari_repo_try1:
  cmd:
    - run
    - name: curl -o /etc/apt/sources.list.d/ambari.list http://public-repo-1.hortonworks.com/ambari/ubuntu{{ releasever }}/2.x/GA/{{ pillar.hdp2.ambari.version }}/ambari.list
    - unless: 'yum list | grep AMBARI'
    - user: root

ambari_repo:
  cmd:
    - run
    - name: curl -o /etc/apt/sources.list.d/ambari.list http://public-repo-1.hortonworks.com/ambari/ubuntu{{ releasever }}/2.x/updates/{{ pillar.hdp2.ambari.version }}/ambari.list
    - user: root
    - unless: 'apt-cache search | grep AMBARI'
    - require:
      - cmd: ambari_repo_try1

{% elif grains['os_family'] == 'RedHat' %}

# Hortonworks has 2 different yum repos that they put their distros in - we'll try both of them here to see which one works
ambari_repo_try1:
  cmd:
    - run
    - name: curl -o /etc/yum.repos.d/ambari.repo http://public-repo-1.hortonworks.com/ambari/centos{{ releasever }}/2.x/GA/{{ pillar.hdp2.ambari.version }}/ambari.repo
    - unless: 'yum list | grep AMBARI'
    - user: root

ambari_repo:
  cmd:
    - run
    - name: curl -o /etc/yum.repos.d/ambari.repo http://public-repo-1.hortonworks.com/ambari/centos{{ releasever }}/2.x/updates/{{ pillar.hdp2.ambari.version }}/ambari.repo
    - user: root
    - unless: 'yum list | grep AMBARI'
    - require:
      - cmd: ambari_repo_try1

{% endif %}

