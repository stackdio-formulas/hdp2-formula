repo_placeholder:
  cmd:
    - run
    - name: which java
    - cmd: hortonworks_repo

{% if grains['os_family'] == 'Debian' %}

# Set up the HDP2 apt repositories
hortonworks_repo_try1:
  cmd:
    - run
    - name: curl -o /etc/apt/sources.list.d/hdp.list http://public-repo-1.hortonworks.com/HDP/ubuntu12/2.x/GA/{{ pillar.hdp2.version }}/hdp.list
    - require:
      - file: add_policy_file

# This may not work
hortonworks_repo:
  cmd:
    - run
    - name: curl -o /etc/apt/sources.list.d/hdp.list http://public-repo-1.hortonworks.com/HDP/ubuntu12/2.x/updates/{{ pillar.hdp2.version }}/hdp.list
    - user: root
    - unless: 'apt-cache search | grep HDP'
    - require:
      - cmd: hortonworks_repo_try1

# This is used on ubuntu so that services don't start on install
add_policy_file:
  file:
    - managed
    - name: /usr/sbin/policy-rc.d
    - contents: exit 101
    - user: root
    - group: root
    - mode: 755
    - makedirs: True

remove_policy_file:
  file:
    - absent
    - name: /usr/sbin/policy-rc.d
    - require:
      - file: add_policy_file

{% elif grains['os_family'] == 'RedHat' %}

# Set up the HDP2 yum repositories
hortonworks_repo_try1:
  cmd:
    - run
    - name: curl -o /etc/yum/repos.d/hdp.repo http://public-repo-1.hortonworks.com/HDP/centos6/2.x/GA/{{ pillar.hdp2.version }}/hdp.repo
    - user: root

hortonworks_repo:
  cmd:
    - run
    - name: curl -o /etc/yum/repos.d/hdp.repo http://public-repo-1.hortonworks.com/HDP/centos6/2.x/updates/{{ pillar.hdp2.version }}/hdp.repo
    - user: root
    - unless: 'yum list | grep HDP'
    - require:
      - cmd: hortonworks_repo_try1

{% endif %}

