#!/bin/bash

# ==============================================================================
# Cloudera's kinit tool shorcut
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

SCRIPTNAME=$(basename "${BASH_SOURCE[0]}")

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

# Usage
function usage() {
    echo
    echo "  ${s_bold}SYNOPSIS:${s_reset}"
    echo "    Use ${s_bold}${SCRIPTNAME}${s_reset} to perform a login using a kerberos principal"
    echo
    echo "  ${s_bold}SYNTAX:${s_reset}"
    echo "    ${SCRIPTNAME} <principal_name>"
    echo
}

if [ $# == 0 ]
then
   usage
   exit 1
fi

v_user="$1"
v_keytab=$(find /run/cloudera-scm-agent/process -name "$v_user.keytab" -printf "%T@ %p\n" | sort -n | awk 'END{print $2}')
if [ -z "$v_keytab" ]
then
   echo "${c_red}No keytabs found matching ${s_bold}$v_user${s_reset}"
   exit 2
fi

v_principal=$(klist -kt $v_keytab | awk "\$4~/$v_user/{print \$4;exit}")
if [ -z "$v_principal" ]
then
    echo "${c_red}No principal found matching ${s_bold}$v_user${s_reset}${c_red} in ${s_bold}$v_keytab${s_reset}"
   exit 3
fi

kinit -kt $v_keytab $v_principal && echo "${c_green}Sucessfully logged in as ${s_bold}$v_principal${s_reset}" && echo

klist