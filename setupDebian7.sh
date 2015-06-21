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
# and to see if a package contains a file: dpkg -L zlib1g-dev
###############################################################################

# load some utility functions
. ./natmsg_functions.sh

. ./natmsg_install_functions.sh


###############################################################################
# a few preliminaries:
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
gshc_continue
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


# The data directory changes depending on the 
# OS version and install method

# The gshc_get_os function will set GSHC_OS and GSHC_OS_VER globals.
gshc_get_os;

if [ "${GSHC_OS}" = "Debian" ]; then
    # Debian:
    PGUSER_HOME='/var/lib/postgresql'
    PGSQL_BIN_DIR='/usr/lib/postgresql/9.1/bin'
    PGSQL_DATA='/var/lib/postgresql/9.1/main'
    PGSQL_CONF='/etc/postgresql/9.1/main/postgresql.conf'
elif ( ( [ "${GSHC_OS}" = "CentOS" ] || [ "${GSHC_OS}" = "RedHat" ]) && [ "${GSHC_OS_VER}" = "7" ]); then
    # centos:
    PGUSER_HOME='/home/postgres'
    PGSQL_BIN_DIR='/usr/bin'
    PGSQL_DATA='/var/lib/pgsql/data'
    PGSQL_CONF='/var/lib/pgsql/data/postgresql.conf'
else
    echo "Error. Unexpected OS or version: ${GSHC_OS} version: ${GSHC_OS_VER}"
    gshc_pause
    exit 55744
fi
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

LOG_FILE="${SOURCE_DIR}/natmsg_install-${DSTAMP}.log"

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

if (gshc_confirm "Install basic preliminaries? (y/n): "); then
	initial_installs "${LOG_FILE}";
fi

if (gshc_confirm "Prepare Natural Message directories? (y/n): "); then
    natmsg_dir_setup "${SOURCE_DIR}" "${LOG_FILE}";
fi

natmsg_install_python "${PYTHON_VER}" "${LOG_FILE}";

natmsg_install_postgre "${PGSQL_BIN_DIR}" "${PGSQL_DATA}" "${PGUSER_HOME}" \
    "${PSYCOPG_VER}" "${LOG_FILE}" "${iface}";


if (gshc_confirm "Install cryptogrphy dependencies? (y/n): "); then
    natmsg_install_crypto "${SIX_VER}" "${PYCPARSER_VER}" "${CFFI_VER}" \
        "${PYASN_VER}" "${IDNA_VER}" "${CRYPTOGRAPHY_VER}" "${CRYPTO_VER}"
fi

if (gshc_confirm "Install pyopenssl dependencies? (y/n): "); then
    install_open_ssl;
fi

natmsg_install_cherrypy;

install_self_signed_cert "${CERT_KEY_ROOT}" "${DSTAMP}" ; # user is prompted


if (gshc_confirm "Install the ptyhon requests module? (y/n): "); then
	# The Requests lib for python comes from
	# http://docs.python-requests.org/en/latest/user/install/#get-the-code
	# and the downloaded directory looks something like this:
	# kennethreitz-requests-359659c
	install_python_tar_gz  https://github.com/kennethreitz/requests/archive/master.tar.gz;
fi

install_libgcrypt "${LIBGPGERR_VER}" "${LIBGCRYPT_VER}" "${DSTAMP}";

# yes, install python3 from source again because the
# other installes installed dependencies that are needed
# before I compile python.
natmsg_install_python "${PYTHON_VER}" "${LOG_FILE}";

if (gshc_confirm "Configure postgreSQL? (y/n): "); then
    configure_postgres_sql "${PGUSER_HOME}" "${SOURCE_DIR}";
fi

initialize_natmsg_database "${PGUSER_HOME}" "${PGSQL_BIN_DIR}" \
    "${PGSQL_DATA}" "${DBNAME}";


# Double check for signs that the database was initialized
if ( [ ! -d "${PGSQL_DATA}/base" ] || [ ! -f "${PGSQL_DATA}/postgresql.conf"  ]); then
    echo "Error (947). You do not apear to have a valid database in ${PGSQL_DATA}."
    gshc_continue
    exit 947
fi

install_natmsg_v;

configure_sysmon "${PGUSER_HOME}" "${SOURCE_DIR}";

natmsg_final_config;
###############################################################################
echo "DONE!"
