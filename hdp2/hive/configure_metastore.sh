#!/bin/bash -e

# configure mysql
/usr/bin/mysql_secure_installation <<EOF

n
y
y
y
y
EOF


# create the metastore database
SETUPSQL="/tmp/hive_setup.sql"
cat >$SETUPSQL <<EOF
CREATE DATABASE metastore;
USE metastore;
SOURCE {{pillar.hdp2.hive.home}}/scripts/metastore/upgrade/mysql/hive-schema-0.12.0.mysql.sql;
CREATE USER '{{pillar.hdp2.hive.user}}'@'localhost' IDENTIFIED BY '{{pillar.hdp2.hive.metastore_password}}';
REVOKE ALL PRIVILEGES, GRANT OPTION FROM '{{pillar.hdp2.hive.user}}'@'localhost';
GRANT SELECT,INSERT,UPDATE,DELETE,LOCK TABLES,EXECUTE ON metastore.* TO '{{pillar.hdp2.hive.user}}'@'localhost';
FLUSH PRIVILEGES;
EOF

mysql -u root < $SETUPSQL

# cleanup
rm -f $SETUPSQL


