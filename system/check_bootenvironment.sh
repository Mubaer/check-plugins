#!/usr/local/bin/bash
#
# Checks if there are additional boot environments
#
# 2022-09-11 - v0.1 by Xin Qu
#
callpath=`dirname $0`
LIBPATH=$callpath/../lib
. $LIBPATH/bashPluginFunctions.sh

UNKNOWN_IS_OK=1
if bectl check ; then
	bes=`bectl list -H -c creation`
	count=`echo "$bes" | wc -l | tr -d [[:space:]]`
	if [ $count -gt 1 ] ; then
		msg="There are $count boot environments."
		data='There should only be one in production, otherwise the system will run out of disk space.'
		rc=1
	else	
		msg="There's only 1 boot environments, that's good"
		rc=0
	fi
else
	msg='Boot enviroments not availabe on this system'
	if [ $UNKNOWN_IS_OK -eq 1 ]; then
		rc=0
	else
		rc=3
	fi
fi

exit_status $rc "$msg" "$data"
