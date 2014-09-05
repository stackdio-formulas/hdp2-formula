repo_placeholder:
  cmd:
    - run
    - name: which java


{% if grains['os_family'] == 'Debian' %}
    # The require stmt for the above placeholder
    - require:
      - cmd: hdp2_gpg

# Set up the HDP2 apt repositories
HDP-{{ pillar.hdp2.version }}:
  pkgrepo:
    - managed
    - name: deb http://public-repo-1.hortonworks.com/HDP/ubuntu12/{{ pillar.hdp2.version }} HDP main
    - require:
      - file: add_policy_file

HDP-UTILS-{{ pillar.hdp2.utils_version }}:
  pkgrepo:
    - managed
    - name: deb http://public-repo-1.hortonworks.com/HDP-UTILS-{{ pillar.hdp2.utils_version }}/repos/ubuntu12 HDP-UTILS main
    - require:
      - file: add_policy_file

hdp2_gpg:
  cmd:
    - run
    - name: 'gpg --keyserver pgp.mit.edu --recv-keys B9733A7A07513CAD; gpg -a --export 07513CAD | apt-key add -'
    - unless: 'apt-key list | grep "HDP Builds"'
    - user: root
    - require:
      - pkgrepo: HDP-{{ pillar.hdp2.version }}
      - pkgrepo: HDP-UTILS-{{ pillar.hdp2.utils_version }}

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
    # The require stmt for the above placeholder
    - require:
      - pkgrepo: HDP-{{ pillar.hdp2.version }}
      - pkgrepo: HDP-UTILS-{{ pillar.hdp2.utils_version }}

# Set up the HDP2 yum repositories
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

{% endif %}

