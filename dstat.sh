#!/bin/ksh

# usage ./dstat.sh 1 1000
# run every one second for 1000 times and display information about processes in uninterruptible state

for i in `seq ${2:-1}` ; do
    ps -e -o stat:5,tid:8,user,wchan:17,cmd:70 | grep '^D' && date
    if [ $? = 0 ] ; then
        for tid in $(ps -u${USER} -o stat:5,tid:8 | grep -P -o '(?<=^D....).*') ; do
            echo ===== $tid
            cat /proc/$tid/stack
        done
    fi

    sleep ${1:-0}
done
