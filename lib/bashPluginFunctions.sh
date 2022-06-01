exit_status () {
    local rc=$1
    local msg=$2
    local data=$3

    local status[0]='[OK]'
    local status[1]='[WARNING]'
    local status[2]='[CRITICAL]'
    local status[3]='[UNKNOWN]'

    echo -e "${status[$rc]}: $msg"
    if [ -n "$data" ] ; then
        echo -e "\n$data"
    fi
    exit $rc
}
