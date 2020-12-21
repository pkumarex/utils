#!/bin/bash

if [ "$1" = "start" ]
then
    ulimit -n 50000
    ./ta-sim start &>> logs/tagent-sim.log &
elif [ "$1" = "stop" ]
then
    ps axf | grep ta-sim | grep -v grep | awk '{print "kill -9 " $1}' | sh
elif [ "$1" = "restart" ]
then
    ulimit -n 50000
    ./ta-sim start &>> logs/tagent-sim.log &
    sleep 2
    ps axf | grep ta-sim | grep -v grep | awk '{print "kill -9 " $1}' | sh
elif [ "$1" = "create-all-hosts" ]
then
    ./ta-sim create-all-hosts &>> logs/tagent-sim.log &
elif [ "$1" = "create-all-flavors" ]
then
    ./ta-sim create-all-flavors &>> logs/tagent-sim.log &
elif [ "$1" = "version" ]
then
    ./ta-sim version
else
    echo "   ####### Trustagent Simulator ####### "
    echo " tagent-sim.sh start              : To start simulator "
    echo " tagent-sim.sh stop               : To stop simulator"
    echo " tagent-sim.sh restart            : To restart simulator"
    echo " tagent-sim.sh create-all-hosts   : To create all hosts"
    echo " tagent-sim.sh create-all-flavors : To create all flavors"
fi
