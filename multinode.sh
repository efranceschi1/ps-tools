#! /bin/bash

# ==============================================================================
# This script executes commands in multiple nodes using SSH
# ==============================================================================
#
# DISCLAIMER
#
# Please note: This script is released for use "AS IS" without any warranties
# of any kind, including, but not limited to their installation, use, or
# performance. We disclaim any and all warranties, either express or implied,
# including but not limited to any warranty of noninfringement,
# merchantability, and/ or fitness for a particular purpose. We do not warrant
# that the technology will meet your requirements, that the operation thereof
# will be uninterrupted or error-free, or that any errors will be corrected.
#
# Any use of these scripts and tools is at your own risk. There is no guarantee
# that they have been through thorough testing in a comparable environment and
# we are not responsible for any damage or data loss incurred with their use.
#
# You are responsible for reviewing and testing any scripts you run thoroughly
# before use in any non-testing environment.
# ==============================================================================

# http://redsymbol.net/articles/unofficial-bash-strict-mode/
set -u

# ANSI
s_bold=$(tput bold)
s_reset=$(tput sgr0)
c_red=$(tput setaf 1)
c_green=$(tput setaf 2)
c_yellow=$(tput setaf 3)
i_ok="✓"
i_nok="✗"

# Info
VER=1.0.0

# Global Variables
SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")
BASE_LOG_DIR=/tmp/multiexec_${USER}
LOG_DIR=${BASE_LOG_DIR}/$(date '+%Y-%m-%d')
CFG_DIR=$HOME/.ps-tools
CFG_FILE=$CFG_DIR/config
HOSTS_FILE=$CFG_DIR/hosts


# Commands
SSH_OPTS="-oPasswordAuthentication=no -oStrictHostKeyChecking=no -oCheckHostIP=no"

# Initialization
function init() {
    test -d $CFG_DIR || mkdir -p $CFG_DIR
    test -d $LOG_DIR || mkdir -p $LOG_DIR
    test -f $HOSTS_FILE || {
        echo "# Please enter one host per line"
    } > $HOSTS_FILE
    test -f $CFG_FILE || {
        echo "SSH_USER=\"$USER\""
        echo "SSH_OPTS=\"$SSH_OPTS\""
        echo "HOSTS_FILE=\"$HOSTS_FILE\""
    } > $CFG_FILE
}

# Usage
function usage() {
    echo
    echo "  ${s_bold}SYNOPSIS:${s_reset}"
    echo "    Use ${s_bold}${SCRIPTNAME}${s_reset} to execute commands sync/async in multiple nodes at once"
    echo
    echo "  ${s_bold}SYNTAX:${s_reset}"
    echo "    ${SCRIPTNAME} [options] command [arg 1] [arg 2] [arg n]"
    echo
    echo "  ${s_bold}Immediate commands:${s_reset}"
    echo "    -h   Show this message"
    echo "    -e   Edit hosts file"
    echo "    -i   Install SSH Key for passwordless login"
    echo "    -r,  Remove logs directory"
    echo "    -t,  Test SSH access to all hosts"
    echo "    -s,  Show hosts"
    echo "    -v   Show version"
    echo
    echo "  ${s_bold}Options when running commands:${s_reset}"
    echo "    -a   Run commands in asynchronous mode instead of synchronous"
    echo
}

# Now
function now() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Clean Logs
function remove_logs() {
    echo "Removing logs from ${BASE_LOG_DIR}"
    rm -fr ${BASE_LOG_DIR}
}

# Logging
function log() {
    hostname=$1; shift
    sed "s/^/$hostname: /" | tee "$LOG_DIR/$hostname.log" 2>&1
}

# Count hosts
function count_hosts() {
    count=$(sed '/^#/d' $HOSTS_FILE | wc -l)
    echo "$[count+0] hosts found in $HOSTS_FILE"
}

# Get hosts
function get_hosts() {
    sed "/^#/d" $HOSTS_FILE
}

# Show hosts
function list_hosts() {
    sed "/^#/d;s/.*/${c_green}${i_ok} &${s_reset}/" $HOSTS_FILE
}

# Edit hosts
function edit_hosts() {
    vi $HOSTS_FILE
}

# Test host
function test_host() {
    ssh $SSH_OPTS -l "$SSH_USER" "$1" "hostname -f" >/dev/null 2>&1
}

# Test hosts
function test_hosts() {
    echo "${s_bold}Testing SSH connection...${s_reset}"
    for h in $(get_hosts)
    do
        (test_host $h && echo " ${c_green}${i_ok} $h${s_reset}" || echo " ${c_red}${i_nok} $h${s_reset}") &
    done
    wait
}

# Install SSH Key
function install_ssh_key() {
    echo -n "Enter the password for user $SSH_USER: "
    read -s password
    echo
    for h in $(get_hosts)
    do
        echo -n "Installing the ssh key into $h..."
        /usr/bin/expect <<EXPECT > /dev/null 2>&1
        spawn ssh-copy-id -oStrictHostKeyChecking=no -oCheckHostIP=no $SSH_USER@$h
        expect "assword"
        send "$password\r"
        expect eof
EXPECT
        test_host $h && echo "${c_green} ${i_ok}${s_reset}" || echo " ${c_red} ${i_nok}${s_reset}"
    done
}

# Option Variables
OPT_ASYNC=""

# Init
init
source $CFG_FILE

# Command line parsing
while getopts "heirstva" options
do
    case "$options" in
    h)
        usage
        exit 1
        ;;
    e)
        edit_hosts
        exit $?
        ;;
    i)
        install_ssh_key
        exit $?
        ;;
    r)
        remove_logs
        exit $?
        ;;
    s)
        list_hosts
        count_hosts
        exit $?
        ;;
    t)
        test_hosts
        exit 0
        ;;
    v)
        echo "$SCRIPTNAME version $VER"
        exit 0
        ;;
    a)
        OPT_ASYNC=1
        echo "Asynchronous mode is ${c_green}ON${s_reset}"
        ;;
    *)
        usage
        exit 1
        ;;
    esac
done

# Command
shift $[OPTIND-1]
CMD="$@"

if [ -z "$CMD" ]
then 
    usage
    exit 1
fi

# Execute commands
for h in $(get_hosts)
do
    function cmd() {
        (
            start_time="$(date +%s)"
            echo "${s_bold}==> [$(now)] BEGIN COMMAND ${c_yellow}\"$CMD\"${s_reset}${s_bold} ON HOST: ${c_yellow}$h${s_reset}"
            ssh $SSH_OPTS -l $SSH_USER $h "$CMD" 2>&1
            end_time="$(date +%s)"
            elapsed_time=$[end_time-start_time]
            echo "${s_bold}<== [$(now)] END COMMAND ${c_yellow}\"$CMD\"${s_reset}${s_bold} ON HOST: ${c_yellow}$h${s_reset}${s_bold} WITH EXIT CODE ${c_yellow}$?${s_reset}${s_bold} in ${c_yellow}${elapsed_time} seconds${s_reset}"
        ) | tee -a "$LOG_DIR/$h.log" 2>&1
    }
    if [ -z "$OPT_ASYNC" ]
    then
        cmd 
    else
        cmd | sed "s/^/$h: /" &
    fi
done
if [ ! -z "$OPT_ASYNC" ]
then
    wait
fi

# Log message
echo "${s_bold}*** [$(now)] ALL LOGS ARE AVAILABLE AT: ${c_yellow}$LOG_DIR${s_reset}"