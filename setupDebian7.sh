#!/bin/bash


# Note: this scripted uses a few commands that are
# unique to bash that do not work in other
# shell scripts.  the /bin/sh command is sometimes
# pointed to csh or bash or another shell program,
# so I point to bash specifically.
###############################################################################
# Copyright 2015 Natural Message, LLC.
# Author: Robert Hoot (naturalmessage@fastmail.fm)
#
# This file is part of the Natural Message Shard Server.
#
# The Natural Message Shard Server is free software: you can redistribute
# it and/or modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation, either version 3 of
# the License, or (at your option) any later version.
#
# Natural Message Shard Server is distributed in the hope that it will
# be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Natural Message Shard Server.  If not, see
# <http://www.gnu.org/licenses/>.
###############################################################################


# Finding packages on Debian:
# The command "dpkg-query -l 'python*'" showed python3 but without
# a version number.
# Also use apt-cache search PKGNAME
###############################################################################

# load some utility functions
. ./natmsg_functions.sh

. ./natmsg_install_functions.sh

###############################################################################
# a few preliminaries:
apt-get update
apt-get upgrade
apt-get -y install screen curl vim sudo
###############################################################################

echo "This is a setup for the shard server for Debian 7 (it also does"
echo "most of the setup for the directory server)."
echo 
echo "You should run this on a clean install of Debian 7--do not try to"
echo "install this on a server that has other servers or other python"
echo "apps because there is a good chance that there will be conflicts."
echo
echo "Before continuing, you should probably run this under the 'screen'"
echo "or 'tmux' screen manager on the remote server so that you can go "
echo "to the other screen (on the remote server) to run a few commands."
read -p  "Press ENTER to continue or Ctl-c to quit." junk
echo
echo "This install script will do several things, including installing "
echo "an updated version of SSL that can handle elliptic curve cryptography,"
echo "installing several packages for python (for cryptography, web request,"
echo "etc.).  Things must be installed in"
echo "the proper order so that Python has all the requirements before it is"
echo "compiled. One key dependency is the updated SSL so that the _ssl "
echo "library under ssl.py is ready before compiliing Python 3."
echo 
echo "You might have to update /etc/apt/sources.list to add a line that"
echo "starts with 'deb-src' (with a url), then run:"
echo "deb-src http://http.us.debian.org/debian stable main"
echo "##deb-src http://non-us.debian.org/debian-non-US stable/non-US "
echo "main contrib non-free"
echo "   sudo apt-get update "
echo "See https://wiki.debian.org/SourcesList"
echo ""
gshc_continue;
###############################################################################
#                     CHECK EACH OF THESE OPTIONS
#
SOURCE_DIR=$(pwd)
# Interfaces are listed in /etc/sysconfig/network-scripts/ifcfg-*
clear
gshc_select_interface "Enter a number to select a Network Interface " \
    "(e.g., Ethernet card) that will be used for the PostgreSQL " \
    "database (enter a number): "
iface="${G_IF_NAME}"
echo "Using network interface ${iface}"


PGUSER_HOME='/var/lib/postgresql'  # on centOS, I use /home/postgres
PGSQL_DATA='/var/lib/postgresql/9.1/main' #debian
PGSQL_BIN_DIR='/usr/lib/postgresql/9.1/bin'
PGSQL_CONF='/etc/postgresql/9.1/main/postgresql.conf'
PYTHON_VER="3.4.3" # for source install only
PSYCOPG_VER="2.6" # version used in the download for psychopg2

LIBGCRYPT_VER="libgcrypt-1.6.3"
LIBGPGERR_VER="libgpg-error-1.19"

SIX_VER="1.9.0"
PYCPARSER_VER="2.14"
CFFI_VER="1.1.2"
PYASN_VER="0.1.7"
IDNA_VER="2.0"
CRYPTOGRAPHY_VER="0.9.1"  # https://pypi.python.org/pypi/cryptography
CRYPTO_VER="2.6.1"  # https://pypi.python.org/pypi/pycrypto

is_64=$(uname -m|grep 64)
if [ -z "${is_64}" ]; then
    ARCHBITS="32"
else
    ARCHBITS="64"
fi


CERT_KEY_ROOT='/var/natmsg/private'

DBNAME='shardsvrdb' 

DSTAMP=`date +"%Y%m%d%H%M%S"`

MENU_PYOPENSSL="`cat <<EOF
1) Skip this
   step.
2) Reinstall from the 
  current files.
3) Download and 
   reinstall PYOpenSSL.
EOF
`"
###############################################################################
clear
echo "########################################################################"
echo "           CHECK EACH OPTION"
echo ""
echo "PGUSER_HOME       ${PGUSER_HOME}"
echo "PGSQL_DATA        ${PGSQL_DATA}"
echo "PGSQL_BIN_DIR         ${PGSQL_BIN_DIR}"
echo "PGSQL_CONF        ${PGSQL_CONF}"
echo "LIBGCRYPT_VER     ${LIBGCRYPT_VER}"
echo "LIBGPGERR_VER     ${LIBGPGERR_VER}"
echo "ARCHBITS          ${ARCHBITS}"
echo "PYTHON_VER        ${PYTHON_VER}"
echo "PSYCOPG_VER       ${PSYCOPG_VER}"
echo "DSTAMP            ${DSTAMP}"
echo "initdb command :  sudo -u postgres ${PGSQL_BIN_DIR}/pg_ctl " \
    "-D ${PGSQL_DATA} initdb"
gshc_continue;

# NOW RUN THE SCRIPT FUNCTIONS TO INSTALL EVERYTHING

initial_installs;

natmsg_dir_setup "${SOURCE_DIR}";

natmsg_install_python "${PYTHON_VER}";

natmsg_install_postgre ${PGSQL_BIN_DIR}" ${PGSQL_DATA}" ${PGUSER_HOME}" \
    ${PSYCOPG_VER}";

natmsg_install_cherrypy;

natmsg_install_crypto ${six_ver} ${pycparser_ver} ${cffi_ver} \
    ${pyasn_ver} ${idna_ver} ${cryptography_ver} ${crypto_ver}

install_open_ssl;

install_self_signed_cert "${CERT_KEY_ROOT}" "${DSTAMP}" ; # user is prompted

# The Requests lib for python comes from
# http://docs.python-requests.org/en/latest/user/install/#get-the-code
# and the downloaded directory looks something like this:
# kennethreitz-requests-359659c
install_python_tar_gz  https://github.com/kennethreitz/requests/archive/master.tar.gz;

install_libgcrypt "${LIBGPGERR_VER}" "${LIBGCRYPT_VER}" "${DSTAMP}";

configure_postgres_sql "${PGUSER_HOME}" "${SOURCE_DIR}";

configure_sysmon "${PGUSER_HOME}" "${SOURCE_DIR}";


initialize_natmsg_database "${PGUSER_HOME}" "${PGSQL_BIN_DIR}" \
    "${PGSQL_DATA}" "${DBNAME}";

install_natmsg_v;

natmsg_final_config;
###############################################################################
echo "DONE!"
