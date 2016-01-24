#!/bin/ksh

# Run a process and sample its waiting channel every 0.1s 
#
# Usage:
#    ./chantime.sh dd if=/dev/zero of=zer count=10 bs=4096 conv=notrunc,fdatasync


$@ &
BPID=$!

CURWCHAN=""
CURTIME=0

while [ 1 = 1 ] ; do
	RES=$(ps -o wchan --no-heading -p $BPID) || break
	sleep 0.1
	if [ "$RES" = "${CURWCHAN}" ] ; then
		CURTIME=$((CURTIME + 0.1))
	else
		if [ $CURTIME -gt 0 ] ; then
			echo $CURWCHAN $CURTIME
		fi
		CURWCHAN=${RES}
		CURTIME=0.1
	fi
done

if [ $CURTIME -gt 0 ] ; then
	echo $CURWCHAN $CURTIME
fi

