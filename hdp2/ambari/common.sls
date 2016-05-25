
include:
  - hdp2.ambari.repo

needed-pkgs:
  pkg:
    - installed
    - pkgs:
      - scp
      - curl
      - unzip
      - tar
      - wget
    - require:
      - cmd: ambari_repo
