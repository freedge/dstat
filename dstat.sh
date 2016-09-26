#!/bin/ksh

# usage ./dstat.sh 1 1000
# run every one second for 1000 times and display information about processes in uninterruptible state

# don't get caught into an fadvise64, see
# https://build.opensuse.org/package/view_file/Base:System/glibc/glibc-2.3.90-ld.so-madvise.diff?rev=25
export LD_NOMADVISE=NOMADVISE

COUNT=0
while [[ ${COUNT} -lt ${2:-1} ]] ; do
    COUNT=$(( ${COUNT} + 1 ))
    ps -T -e -o stat:5,tid:8,user,wchan:17,cmd:70 | grep '^D'  && date
    sleep ${1:-0}
done
