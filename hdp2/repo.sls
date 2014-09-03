{% if grains['os_family'] == 'Debian' %}

# Add the appropriate CDH5 repository. See http://archive.cloudera.com/cdh5
# for which distributions and versions are supported.
/etc/apt/sources.list.d/cloudera.list:
  file:
    - managed
    - name: /etc/apt/sources.list.d/cloudera.list
    - source: salt://cdh5/etc/apt/sources.list.d/cloudera.list.template
    - user: root
    - group: root
    - mode: 644
    - template: jinja
    - require:
      - file: add_policy_file

cdh5_gpg:
  cmd:
    - run
    - name: 'curl -s http://archive.cloudera.com/cdh5/ubuntu/{{ grains["lsb_distrib_codename"] }}/amd64/cdh/archive.key | apt-key add -'
    - unless: 'apt-key list | grep "Cloudera Apt Repository"'
    - require:
      - file: /etc/apt/sources.list.d/cloudera.list

cdh5_refresh_db:
  module:
    - run
    - name: pkg.refresh_db
    - require:
      - cmd: cdh5_gpg

# This is used on ubuntu so that services don't start 
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

# Set up the CDH5 yum repository
HDP-{{ pillar.hdp2.version }}:
  pkgrepo:
    - managed
    - humanname: "Hortonworks Data Platform Version - HDP-{{ pillar.hdp2.version }}"
    - baseurl: "http://public-repo-1.hortonworks.com/HDP/centos6/2.x/updates/{{ pillar.hdp2.version }}"
    - gpgkey: "http://public-repo-1.hortonworks.com/HDP/centos6/2.x/updates/{{ pillar.hdp2.version }}/RPM-GPG-KEY/RPM-GPG-KEY-Jenkins"
    - gpgcheck: 0
    - enabled: 1
    - priority: 1

HDP-UTILS-{{ pillar.hdp2.utils_version }}:
  pkgrepo:
    - managed
    - humanname: "Hortonworks Data Platform Utils Version - HDP-UTILS-{{ pillar.hdp2.utils_version }}"
    - baseurl: "http://public-repo-1.hortonworks.com/HDP-UTILS-{{ pillar.hdp2.utils_version }}/repos/centos6"
    - gpgkey: "http://public-repo-1.hortonworks.com/HDP/centos6/2.x/updates/{{ pillar.hdp2.version }}/RPM-GPG-KEY/RPM-GPG-KEY-Jenkins"
    - gpgcheck: 1
    - enabled: 1
    - priority: 1

#cdh5_gpg:
#  cmd:
#    - run
#    - name: 'rpm --import http://archive.cloudera.com/cdh5/redhat/6/x86_64/cdh/RPM-GPG-KEY-cloudera'
#    - unless: 'rpm -qi gpg-pubkey-e8f86acd'
#    - require:
#      - pkgrepo: cloudera_cdh5

cdh5_refresh_db:
  module:
    - run
    - name: pkg.refresh_db
    - require:
      - pkgrepo: HDP-{{ pillar.hdp2.version }}
      - pkgrepo: HDP-UTILS-{{ pillar.hdp2.utils_version }}

{% endif %}

