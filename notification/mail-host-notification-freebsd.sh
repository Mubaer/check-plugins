#!/usr/bin/env bash
# Icinga 2 | (c) 2012 Icinga GmbH | GPLv2+
# Except of function urlencode which is Copyright (C) by Brian White (brian@aljex.com) used under MIT license
# Modified and enhanced by m.sander@mr-daten.de 2022

PROG="`basename $0`"
ICINGA2HOST="`hostname`"
# fixed mail binary b/c we use 'mailutils'-package
MAILBIN="/usr/local/bin/mail"

if [ -z "`which $MAILBIN`" ] ; then
  echo "$MAILBIN not found in \$PATH. Consider installing it."
  exit 1
fi

## Function helpers
Usage() {
cat << EOF

Required parameters:
  -d LONGDATETIME (\$icinga.long_date_time\$)
  -l HOSTNAME (\$host.name\$)
  -n HOSTDISPLAYNAME (\$host.display_name\$)
  -o HOSTOUTPUT (\$host.output\$)
  -r USEREMAIL (\$user.email\$)
  -s HOSTSTATE (\$host.state\$)
  -t NOTIFICATIONTYPE (\$notification.type\$)

Optional parameters:
  -4 HOSTADDRESS (\$address\$)
  -6 HOSTADDRESS6 (\$address6\$)
  -b NOTIFICATIONAUTHORNAME (\$notification.author\$)
  -c NOTIFICATIONCOMMENT (\$notification.comment\$)
  -i ICINGAWEB2URL (\$notification_icingaweb2url\$, Default: unset)
  -f MAILFROM (\$notification_mailfrom\$, requires GNU mailutils (Debian/Ubuntu) or mailx (RHEL/SUSE))
  -v (\$notification_sendtosyslog\$, Default: false)

EOF
}

Help() {
  Usage;
  exit 0;
}

Error() {
  if [ "$1" ]; then
    echo $1
  fi
  Usage;
  exit 1;
}

urlencode() {
  local LANG=C i=0 c e s="$1"

  while [ $i -lt ${#1} ]; do
    [ "$i" -eq 0 ] || s="${s#?}"
    c=${s%"${s#?}"}
    [ -z "${c#[[:alnum:].~_-]}" ] || c=$(printf '%%%02X' "'$c")
    e="${e}${c}"
    i=$((i + 1))
  done
  echo "$e"
}

quoted_printable () {
    perl -MMIME::QuotedPrint -s -ne '
        BEGIN { *e = $d ? \&decode_qp : \&encode_qp }
        print e $_
    ' -- "$@"
}

getemoticon() {
    local state=$1
    case $state in
        RECOVERY)
            emo=':-)'   ;;
        PROBLEM)
            emo=':-('   ;;
        ACKNOWLEDGEMENT)
            emo=':-|'   ;;
        *)  
            emo=''      ;;
    esac
    echo "$emo"
}

## Main
while getopts 4:6::b:c:d:f:hi:l:n:o:r:s:t:v: opt
do
  case "$opt" in
    4) HOSTADDRESS=$OPTARG ;;
    6) HOSTADDRESS6=$OPTARG ;;
    b) NOTIFICATIONAUTHORNAME=$OPTARG ;;
    c) NOTIFICATIONCOMMENT=$OPTARG ;;
    d) LONGDATETIME=$OPTARG ;; # required
    f) MAILFROM=$OPTARG ;;
    h) Help ;;
    i) ICINGAWEB2URL=$OPTARG ;;
    l) HOSTNAME=$OPTARG ;; # required
    n) HOSTDISPLAYNAME=$OPTARG ;; # required
    o) HOSTOUTPUT=$OPTARG ;; # required
    r) USEREMAIL=$OPTARG ;; # required
    s) HOSTSTATE=$OPTARG ;; # required
    t) NOTIFICATIONTYPE=$OPTARG ;; # required
    v) VERBOSE=$OPTARG ;;
   \?) echo "ERROR: Invalid option -$OPTARG" >&2
       Error ;;
    :) echo "Missing option argument for -$OPTARG" >&2
       Error ;;
    *) echo "Unimplemented option: -$OPTARG" >&2
       Error ;;
  esac
done

shift $((OPTIND - 1))

## Keep formatting in sync with mail-service-notification.sh
for P in LONGDATETIME HOSTNAME HOSTDISPLAYNAME HOSTOUTPUT HOSTSTATE USEREMAIL NOTIFICATIONTYPE ; do
	eval "PAR=\$${P}"

	if [ ! "$PAR" ] ; then
		Error "Required parameter '$P' is missing."
	fi
done

## Build the message's subject
SUBJECT="[$NOTIFICATIONTYPE | $HOSTSTATE] Host '$HOSTDISPLAYNAME'"

## Pipe subject through quoted-printable encoder
# commented out on 2022-08-02, does not work reliable
#SUBJECT=$( echo "$SUBJECT" | quoted_printable -e )
#SUBJECT="=?UTF-8?Q?${SUBJECT}?="

## Set emoticon for notificationtype
emoti=`getemoticon $NOTIFICATIONTYPE`

## Build the notification message
NOTIFICATION_MESSAGE=`cat << EOF
--------------------------------------------------------------------

                MR Datentechnik Monitoring System

--------------------------------------------------------------------

                -=   $emoti $NOTIFICATIONTYPE $emoti   =-


$HOSTDISPLAYNAME is $HOSTSTATE!

Info:    $HOSTOUTPUT

Host:    $HOSTNAME
EOF
`

## Check whether IPv4 was specified.
if [ -n "$HOSTADDRESS" ] ; then
  NOTIFICATION_MESSAGE="$NOTIFICATION_MESSAGE
IPv4:	 $HOSTADDRESS"
fi

## Check whether IPv6 was specified.
if [ -n "$HOSTADDRESS6" ] ; then
  NOTIFICATION_MESSAGE="$NOTIFICATION_MESSAGE
IPv6:	 $HOSTADDRESS6"
fi

## Check whether author and comment was specified.
if [ -n "$NOTIFICATIONCOMMENT" ] ; then
  NOTIFICATION_MESSAGE="$NOTIFICATION_MESSAGE

Comment by $NOTIFICATIONAUTHORNAME:
  $NOTIFICATIONCOMMENT"
fi

## Check whether Icinga Web 2 URL was specified.
if [ -n "$ICINGAWEB2URL" ] ; then
  NOTIFICATION_MESSAGE="$NOTIFICATION_MESSAGE

Link to IcingaWeb:
------------------
$ICINGAWEB2URL/monitoring/host/show?host=$(urlencode "$HOSTNAME")"
fi

## Append parsable line for ticket-automation
NOTIFICATION_MESSAGE="$NOTIFICATION_MESSAGE



- - - - - - - technical details - - - - - - - - -
This Notification was sent from $ICINGA2HOST
at $LONGDATETIME

[Type:\"host\";Host:\"$HOSTNAME\";Service:\"none\"]
- - - - - - - - - - - - - - - - - - - - - - - - -
"

## Check whether verbose mode was enabled and log to syslog.
if [ "$VERBOSE" = "true" ] ; then
  logger "$PROG sends $SUBJECT => $USEREMAIL"
fi

## Send the mail using the $MAILBIN command.
## If an explicit sender was specified, try to set it.
if [ -n "$MAILFROM" ] ; then

  ## Modify this for your own needs!

  ## Debian/Ubuntu use mailutils which requires `-a` to append the header
  if [ -f /etc/debian_version -o -f /etc/pkg/FreeBSD.conf ]; then
    /usr/bin/printf "%b" "$NOTIFICATION_MESSAGE" | $MAILBIN -a "From: $MAILFROM" -s "$SUBJECT" $USEREMAIL
  ## Other distributions (RHEL/SUSE/etc.) prefer mailx which sets a sender address with `-r`
  else
    /usr/bin/printf "%b" "$NOTIFICATION_MESSAGE" | $MAILBIN -r "$MAILFROM" -s "$SUBJECT" $USEREMAIL
  fi

else
  /usr/bin/printf "%b" "$NOTIFICATION_MESSAGE" \
  | $MAILBIN -s "$SUBJECT" $USEREMAIL
fi
