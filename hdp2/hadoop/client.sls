include:
  - hdp2.repo

hadoop-client: 
  pkg:
    - installed
    - require:
      - cmd: repo_placeholder

