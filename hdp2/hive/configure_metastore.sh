#!/bin/bash -e

# configure mysql
/usr/bin/mysql_secure_installation <<EOF

n
y
y
y
y
EOF

HIVE_VERSION=`hive --version | head -n1 | cut -d ' ' -f2 | cut -d '-' -f1 | cut -d '.' -f2`

# create the metastore database
SETUPSQL="/tmp/hive_setup.sql"
cat >$SETUPSQL <<EOF
CREATE DATABASE metastore;
USE metastore;
SOURCE {{pillar.hdp2.hive.home}}/scripts/metastore/upgrade/mysql/hive-schema-0.$HIVE_VERSION.0.mysql.sql;
CREATE USER '{{pillar.hdp2.hive.user}}'@'localhost' IDENTIFIED BY '{{pillar.hdp2.hive.metastore_password}}';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM '{{pillar.hdp2.hive.user}}'@'localhost';
GRANT SELECT,INSERT,UPDATE,DELETE,LOCK TABLES,EXECUTE ON metastore.* TO '{{pillar.hdp2.hive.user}}'@'localhost';
FLUSH PRIVILEGES;
EOF

mysql -u root < $SETUPSQL

# cleanup
rm -f $SETUPSQL


