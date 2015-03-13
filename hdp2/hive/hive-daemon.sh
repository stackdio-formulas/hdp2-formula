#!/usr/bin/env bash

# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

{% if pillar.hdp2.version.split('.')[1] | int >= 2 %}
{% set hive_home = '/usr/hdp/current/hive-metastore' %}
{% else %}
{% set hive_home = '/usr/lib/hive' %}
{% endif %}

usage="Usage: hive-daemon.sh (start|stop) <hive-command>"

# if no args specified, show usage
if [ $# -le 1 ]; then
  echo $usage
  exit 1
fi

export HIVE_HOME={{ hive_home }}
export HIVE_CONF_DIR=$HIVE_HOME/conf

bin=$HIVE_HOME/bin


startStop=$1
shift
command=$1
shift

if [ -f "${HIVE_CONF_DIR}/hive-env.sh" ]; then
  . "${HIVE_CONF_DIR}/hive-env.sh"
fi

pid=/var/run/hive/$command.pid
log=/var/log/hive/$command.out
errlog=/var/log/hive/$command.log

case $startStop in

  (start)

    if [ -f $pid ]; then
      if kill -0 `cat $pid` > /dev/null 2>&1; then
        echo $command running as process `cat $pid`.  Stop it first.
        exit 1
      fi
    fi

    echo starting $command, logging to $log
    case $command in
      hive-metastore)
        nohup $bin/hive --service metastore >"$log" 2>"$errlog" < /dev/null &
      ;;
      hive-server2)
        nohup $bin/hiveserver2 >"$log" 2>"$errlog" < /dev/null &
      ;;
      (*)
        echo $command not found
      ;;
    esac
    echo $! > $pid
    sleep 1
    head "$log"
    sleep 3;
    if ! ps -p $! > /dev/null ; then
      exit 1
    fi
    ;;

  (stop)

    if [ -f $pid ]; then
      TARGET_PID=`cat $pid`
      if kill -0 $TARGET_PID > /dev/null 2>&1; then
        echo stopping $command
        kill $TARGET_PID
        sleep 5
        if kill -0 $TARGET_PID > /dev/null 2>&1; then
          echo "$command did not stop gracefully after 5 seconds: killing with kill -9"
          kill -9 $TARGET_PID
        fi
      else
        echo no $command to stop
      fi
      rm -f $pid
    else
      echo no $command to stop
    fi
    ;;

  (*)
    echo $usage
    exit 1
    ;;

esac