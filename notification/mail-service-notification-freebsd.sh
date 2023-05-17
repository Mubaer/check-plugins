#!/usr/bin/env bash
# Icinga 2 | (c) 2012 Icinga GmbH | GPLv2+
# Except of function urlencode which is Copyright (C) by Brian White (brian@aljex.com) used under MIT license
# Modified and enhanced by m.sander@mr-daten.de 2022

PROG="`basename $0`"
ICINGA2HOST="`hostname`"

#
# Mail Binary Selection
#
# fixed mail binary b/c we use 'mailutils'-package
MAILBIN="/usr/local/bin/mail"
FLAG_MUTT=0
# First, try mutt. Else, try preconfigured MAILBIN
if [ -n "`which mutt`" ] ; then
  MAILBIN=`which mutt`
  FLAG_MUTT=1
elif [ -z "`which $MAILBIN`" ] ; then
  echo "$MAILBIN not found in \$PATH. Consider installing it."
  exit 1
fi

## Function helpers
Usage() {
cat << EOF

Required parameters:
  -d LONGDATETIME (\$icinga.long_date_time\$)
  -e SERVICENAME (\$service.name\$)
  -l HOSTNAME (\$host.name\$)
  -n HOSTDISPLAYNAME (\$host.display_name\$)
  -o SERVICEOUTPUT (\$service.output\$)
  -r USEREMAIL (\$user.email\$)
  -s SERVICESTATE (\$service.state\$)
  -t NOTIFICATIONTYPE (\$notification.type\$)
  -u SERVICEDISPLAYNAME (\$service.display_name\$)

Optional parameters:
  -4 HOSTADDRESS (\$address\$)
  -6 HOSTADDRESS6 (\$address6\$)
  -b NOTIFICATIONAUTHORNAME (\$notification.author\$)
  -c NOTIFICATIONCOMMENT (\$notification.comment\$)
  -k CUSTOMER_NAME (\$host.vars.customer_name\$)
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


center_string() {
    local center_pos=$1
    local string=$2
    local c=0 buffer=''

    local length=${#string}
    local offset=$(( center_pos  - length / 2 ))
    while [ $c -lt $offset ] ; do
        buffer+=' '
        : $(( c++ ))
    done

    echo "${buffer}$string"
}

## Main
while getopts 4:6:b:c:d:e:f:hi:k:l:n:o:r:s:t:u:v: opt
do
  case "$opt" in
    4) HOSTADDRESS=$OPTARG ;;
    6) HOSTADDRESS6=$OPTARG ;;
    b) NOTIFICATIONAUTHORNAME=$OPTARG ;;
    c) NOTIFICATIONCOMMENT=$OPTARG ;;
    d) LONGDATETIME=$OPTARG ;; # required
    e) SERVICENAME=$OPTARG ;; # required
    f) MAILFROM=$OPTARG ;;
    h) Usage ;;
    i) ICINGAWEB2URL=$OPTARG ;;
    k) CUSTOMER_NAME=$OPTARG ;;
    l) HOSTNAME=$OPTARG ;; # required
    n) HOSTDISPLAYNAME=$OPTARG ;; # required
    o) SERVICEOUTPUT=$OPTARG ;; # required
    r) USEREMAIL=$OPTARG ;; # required
    s) SERVICESTATE=$OPTARG ;; # required
    t) NOTIFICATIONTYPE=$OPTARG ;; # required
    u) SERVICEDISPLAYNAME=$OPTARG ;; # required
    v) VERBOSE=$OPTARG ;;
   \?) echo "ERROR: Invalid option -$OPTARG" >&2
       Usage ;;
    :) echo "Missing option argument for -$OPTARG" >&2
       Usage ;;
    *) echo "Unimplemented option: -$OPTARG" >&2
       Usage ;;
  esac
done

shift $((OPTIND - 1))

## Keep formatting in sync with mail-host-notification.sh
for P in LONGDATETIME HOSTNAME HOSTDISPLAYNAME SERVICENAME SERVICEDISPLAYNAME SERVICEOUTPUT SERVICESTATE USEREMAIL NOTIFICATIONTYPE ; do
        eval "PAR=\$${P}"

        if [ ! "$PAR" ] ; then
                Error "Required parameter '$P' is missing."
        fi
done

## Build the message's subject
SUBJECT="[$NOTIFICATIONTYPE | $SERVICESTATE] '$SERVICEDISPLAYNAME' on '$HOSTDISPLAYNAME'"

## Append Customer Name when provided
if [ -n "$CUSTOMER_NAME" ] ; then
    SUBJECT+=" ($CUSTOMER_NAME)"
fi


## Pipe subject through quoted-printable encoder
# commented out on 2022-08-02, does not work reliable
#SUBJECT=$( echo "$SUBJECT" | quoted_printable -e )
#SUBJECT="=?UTF-8?Q?${SUBJECT}?="


## Build 'Host' string

host_message="$HOSTNAME"
## Check whether IPv4 was specified.
if [ -n "$HOSTADDRESS" ] ; then
  host_message="$host_message ($HOSTADDRESS)"
fi

## Check whether IPv6 was specified.
if [ -n "$HOSTADDRESS6" ] ; then
  host_message="$host_message ($HOSTADDRESS6)"
fi

## Define things for formating page
## hline is the reference for page width and centered text
hline='-------------------------------------------------------------------'
## Dashed Version
dline='- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -'
hline_center=$(( ${#hline} / 2 ))

## Set emoticon for notificationtype
emoti=`getemoticon $NOTIFICATIONTYPE`

# Set Customer info 
line_customer=''
if [ -n "$CUSTOMER_NAME" ] ;then
    line_customer=$( center_string $hline_center "KUNDE: '$CUSTOMER_NAME'" )
    line_customer+="\n$dline\n"
fi

## Preformat centered lines
htext=`center_string $hline_center 'MR Datentechnik Monitoring System'`
typeline=`center_string $hline_center "-=   $emoti $NOTIFICATIONTYPE $emoti   =-"`
statusline=`center_string $hline_center "STATUS is **$SERVICESTATE**"`

## Build the notification message
NOTIFICATION_MESSAGE=`cat << EOF
$hline

$htext

$hline
$line_customer

$typeline

$statusline

HostObject: $host_message
Hostname:   $HOSTDISPLAYNAME

Service:    $SERVICEDISPLAYNAME ($SERVICENAME)


Message-Details:
----------------
$SERVICEOUTPUT

EOF
`


## Check whether author and comment was specified.
if [ -n "$NOTIFICATIONCOMMENT" ] ; then
  NOTIFICATION_MESSAGE="$NOTIFICATION_MESSAGE

Comment by $NOTIFICATIONAUTHORNAME:
  $NOTIFICATIONCOMMENT"
fi

## Check whether Icinga Web 2 URL was specified.
if [ -n "$ICINGAWEB2URL" ] ; then
  # START of multiline string
  NOTIFICATION_MESSAGE="$NOTIFICATION_MESSAGE


Link to IcingaWeb:
------------------
$ICINGAWEB2URL/monitoring/service/show?host=$(urlencode "$HOSTNAME")&service=$(urlencode "$SERVICENAME")"
  # END of multiline string
fi

h2text=`center_string $hline_center 'Technical Details'`
## Append parsable line for ticket-automation
NOTIFICATION_MESSAGE="$NOTIFICATION_MESSAGE


$h2text
$dline
This Notification was sent from $ICINGA2HOST
at $LONGDATETIME

[Type:\"service\";Host:\"$HOSTNAME\";Service:\"$SERVICENAME\"]
$dline
"

## Check whether verbose mode was enabled and log to syslog.
if [ "$VERBOSE" = "true" ] ; then
  logger "$PROG sends $SUBJECT => $USEREMAIL"
fi

## Send the mail using the $MAILBIN command.
## If an explicit sender was specified, try to set it.
if [ -n "$MAILFROM" ] ; then

  if [ $FLAG_MUTT -eq 0 ] ; then
      ## Debian/Ubuntu use mailutils which requires `-a` to append the header
      if [ -f /etc/debian_version -o -f /etc/pkg/FreeBSD.conf ]; then
        /usr/bin/printf "%b" "$NOTIFICATION_MESSAGE" | $MAILBIN -a "From: $MAILFROM" -s "$SUBJECT" $USEREMAIL
      ## Other distributions (RHEL/SUSE/etc.) prefer mailx which sets a sender address with `-r`
      else
        /usr/bin/printf "%b" "$NOTIFICATION_MESSAGE" | $MAILBIN -r "$MAILFROM" -s "$SUBJECT" $USEREMAIL
      fi
  else
      # This should work with mutt
      export EMAIL="$MAILFROM"
      /usr/bin/printf "%b" "$NOTIFICATION_MESSAGE" \
      | $MAILBIN -s "$SUBJECT" $USEREMAIL
  fi

else
  /usr/bin/printf "%b" "$NOTIFICATION_MESSAGE" \
  | $MAILBIN -s "$SUBJECT" $USEREMAIL
fi
