#!/bin/ksh

# usage ./dstat.sh 1 1000
# run every one second for 1000 times and display information about processes in uninterruptible state

# don't get caught into an fadvise64, see 
# https://build.opensuse.org/package/view_file/Base:System/glibc/glibc-2.3.90-ld.so-madvise.diff?rev=25
export LD_NOMADVISE=NOMADVISE

# root user will dump the stack of all processes in D state
case ${USER} in
	root) PSOPT=-e ;;
	*)    PSOPT=-u${USER} ;;
esac

for i in `seq ${2:-1}` ; do
    ps -e -o stat:5,tid:8,user,wchan:17,cmd:70 | grep '^D' && date
    if [ $? = 0 ] ; then
        for tid in $(ps ${PSOPT} -o stat:5,tid:8 | grep -P -o '(?<=^D....).*') ; do
            echo ===== $tid
            cat /proc/$tid/stack
        done
    fi

    sleep ${1:-0}
done
