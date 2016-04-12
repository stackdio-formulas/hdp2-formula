#!/bin/bash -e

# configure mysql
/usr/bin/mysql_secure_installation <<EOF

n
y
y
y
y
EOF

# create the synthesys user
SETUPSQL="/tmp/mysql_setup.sql"
cat >${SETUPSQL} <<EOF
GRANT ALL PRIVILEGES ON ranger.* TO 'rangeradmin'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON ranger_audit.* TO 'rangerlogger'@'localhost' IDENTIFIED BY 'password';
GRANT ALL PRIVILEGES ON rangerkms.* TO 'rangerkms'@'localhost' IDENTIFIED BY 'password';
FLUSH PRIVILEGES;
EOF

mysql -u root < ${SETUPSQL}

# cleanup
rm -f ${SETUPSQL}
