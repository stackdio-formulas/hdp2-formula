include:
  - hdp2.repo

pig:
  pkg:
    - installed
    - pkgs:
      - pig
    - require:
      - cmd: repo_placeholder

