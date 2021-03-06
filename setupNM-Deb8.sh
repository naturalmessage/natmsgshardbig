#!/bin/bash

################################################################################
# Copyright 2015-2016 Natural Message, LLC.
# Author: Robert Hoot (naturalmessage@fastmail.fm)
#
# This file is part of the Natural Message Shard Server.
#
# The Natural Message Shard Server is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Natural Message Shard Server is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Natural Message Shard Server.  If not, see <http://www.gnu.org/licenses/>.
################################################################################
# Note: if you are installing this on a Rasberry Pi that runs the Raspbian
# OS, you should first read and run the pisetup.sh script in this directory.
############################################################################
echo "############################################################"
echo "Starting $0"
echo
if [ ! "$EUID" = "0" ]; then
    echo "Error.  You must run this script as root."
    echo "Try rerunning like this:"
    echo "   sudo $0"
    exit 12
fi

################################################################################
ping -c 4 yahoo.com
if [ $? = 0 ]; then
    echo "It looks like you can reach the Internet."
else
    clear
    echo "Warning: It looks like you can not reach the Internet."
    echo "Press Ctl-C to quit and fix your Internet connection,"
    read -p echo "else press ENTER to continue..." junk
fi

apt-get -y install screen

echo "This is a setup for the shard main server (directory server)"
echo "for Debian 8."
echo
echo
echo "STOP!! You should be running this inside of screen or tmux."
read -p "Press ENTER to continue or CTL-c to quit..." junk

################################################################################
# Finding packages on Debian:
# The command "dpkg-query -l 'python*'" showed python3 but without
# a version number.
# Also use apt-cache search PKGNAME
################################################################################
confirm(){
  local tmp_FIN="N"
  local yn=''
  local MY_PROMPT="$1"
  if (test -z "${MY_PROMPT}"); then
    local MY_PROMPT="Do you want to continue? (y/n): "
  fi
  while (test "${tmp_FIN}" = "N"); do
    read -p "$MY_PROMPT" yn

    case "${yn}" in
      # Note: there can be many commands inside the "case"
      # block, but the last one in each block must end with
      # two semicolons.
      'y'|'Y')
        tmp_FIN="Y";;
      'n'|'N')
        tmp_FIN="Y";
        return 12;;
    esac
  done;
  return 0
}

install_it(){
	local pgm_name="$1"
	apt-get -y install ${pgm_name}
	if [ $? = 0 ]; then
		echo "===== successfully installed ${pgm_name}" | tee -a ${LOG_FNAME}
	else
		echo "Error installing ${pgm_name}" | tee -a ${LOG_FNAME}
		echo "I will try again after 60 seconds in case it was a network slowdown.." | tee -a ${LOG_FNAME}
		sleep 60
		apt-get -y install ${pgm_name}
		if [ $? = 0 ]; then
		  echo "===== successfully installed ${pgm_name}" | tee -a ${LOG_FNAME}
		else
		  echo "===== Error installing ${pgm_name}" | tee -a ${LOG_FNAME}
			echo "quitting now." | tee -a ${LOG_FNAME}
			exit 9753
		fi
	fi
}

set_pw(){
    local my_user_id=$1
    while ! passwd $1; do
        passwd $1
        if [ ! $? = 0 ]; then
            echo "Oops.  The password was not set, try again..."
        fi
    done
}

sql_it(){
	local SQL_NM="$1"
	local DB_NM="$2"
  sudo -u postgres psql -c "\i ${SQL_NM}" "${DB_NM}"
	if [ $? = 0 ]; then
		echo "==== successfully processed SQL ${SQL_NM}."  | tee -a ${LOG_FNAME}
	else
		echo "==== Error processing SQL ${SQL_NM}."  | tee -a ${LOG_FNAME}
		exit 7531
	fi
}

################################################################################

echo "Note if you run this in the future after Debian 8 is old..."
echo "You might have to update /etc/apt/sources.list to add a line that"
echo "starts with 'deb-src' (with a url), then run:"
echo "deb-src http://http.us.debian.org/debian stable main"
echo "##deb-src http://non-us.debian.org/debian-non-US stable/non-US main contrib non-free"
echo "   sudo apt-get update "
echo "See https://wiki.debian.org/SourcesList"
echo ""
read -p  "Press ENTER to continue or Ctl-c to quit." junk
###############################################################################
clear
echo "A wired network is best (e.g., plug your computer into the back of your"
echo "wifi router using an Ethernet cable)."
echo
echo "For Raspbian (Debian 8) users, if you are using wifi, you will probably want to specify the interface as:"
echo "   wlan0"
echo "but if you use a wired network, you should probably say:"
echo "   eth0"

read -p "Enter the name of the network interface: " iface
################################################################################
#                     CHECK EACH OF THESE OPTIONS
#
DSTAMP=`date +"%Y%m%d%H%M%S"`
SOURCE_DIR=$(pwd)


PYTHON3_PGM=/usr/bin/python3
PGUSER_HOME='/var/lib/postgresql'  # on centOS, I use /home/postgres
SHARD_DIR="${PGUSER_HOME}/shardsvr"
PGSQL_DATA='/var/lib/postgresql/9.4/main' #debian
PGSQL_BIN='/usr/lib/postgresql/9.4/bin/'
PGSQL_CONF='/etc/postgresql/9.4/main/postgresql.conf'

### options for DIRSVR

LOG_FNAME="${PGUSER_HOME}/setup${DSTAMP}.log"
DIRSVR_DIR="${PGUSER_HOME}/dirsvr/"
#DBNAME='dirsvrdb'
### end options for DIRSVR


# You can check the currently install library versions with
#   apt list |grep gpg
LIBGCRYPT_VER="libgcrypt-1.6.4"
LIBGPGERR_VER="libgpg-error-1.20"
is_64=$(uname -m|grep 64)
if [ -z "${is_64}" ]; then
    ARCHBITS="32"
else
    ARCHBITS="64"
fi

PYTHON_VER="3.4.3" # for source install only
# https://pypi.python.org/pypi/psycopg2
PSYCOPG_VER="2.6.1" # version used in the download for psychopg2

CERT_KEY_ROOT='/var/natmsg/private'

DBNAME='shardsvrdb' 

mkdir -p "${PGUSER_HOME}"

################################################################################
clear
echo "########################################################################"
echo "           CHECK EACH OPTION"
echo ""
echo "iface              ${iface}"
echo "PGUSER_HOME       ${PGUSER_HOME}"
echo "PGSQL_DATA        ${PGSQL_DATA}"
echo "PGSQL_BIN         ${PGSQL_BIN}"
echo "PGSQL_CONF        ${PGSQL_CONF}"
echo "LIBGCRYPT_VER     ${LIBGCRYPT_VER}"
echo "LIBGPGERR_VER     ${LIBGPGERR_VER}"
echo "ARCHBITS          ${ARCHBITS}"
echo "PYTHON_VER        ${PYTHON_VER}"
echo "PSYCOPG_VER       ${PSYCOPG_VER}"
echo "DSTAMP            ${DSTAMP}"
echo "initdb command :  sudo -u postgres ${PGSQL_BIN}/pg_ctl -D ${PGSQL_DATA} initdb"
read -p  "Pres Ctl-c to quit or ENTER to continue" junk


###############################################################################
#
INSTALL_BASICS='n'
read -p "Do you want to install the basic set of Debian packages used on the shard server? (y/n): " INSTALL_BASICS
case $INSTALL_BASICS in
    'n'|'N')
        INSTALL_BASICS='n';;
    'y'|'Y')
        INSTALL_BASICS='y';;
esac

#
INSTALL_PSQL='n'
read -p "Do you want to install PostgreSQL? (y/n): " INSTALL_PSQL
case $INSTALL_PSQL in
    'n'|'N')
        INSTALL_PSQL='n';;
    'y'|'Y')
        INSTALL_PSQL='y';;
esac

#
INSTALL_SHARD_SVR='n'
read -p "Do you want to install the Natural Message shard server python source? (y/n): " INSTALL_SHARD_SVR
case $INSTALL_SHARD_SVR in
    'n'|'N')
        INSTALL_SHARD_SVR='n';;
    'y'|'Y')
        INSTALL_SHARD_SVR='y';;
esac

#
INSTALL_PYSETUP='n'
read -p "Do you want to install Python setuptools (needed to install other stuff)? (y/n): " INSTALL_PYSETUP
case $INSTALL_PYSETUP in
    'n'|'N')
        INSTALL_PYSETUP='n';;
    'y'|'Y')
        INSTALL_PYSETUP='y';;
esac

#
INSTALL_SSC='n'
read -p "Do you want to generate a self-signed SSL certificate? (y/n): " INSTALL_SSC
case $INSTALL_SSC in
    'n'|'N')
        INSTALL_SSC='n';;
    'y'|'Y')
        INSTALL_SSC='y';;
esac

#
INSTALL_GPG_ERROR='n'
read -p "Do you want to compile gpg-error (required before libgcrypt)? (y/n): " \
    INSTALL_GPG_ERROR
case $INSTALL_GPG_ERROR in
    'n'|'N')
        INSTALL_GPG_ERROR='n';;
    'y'|'Y')
        INSTALL_GPG_ERROR='y';;
esac

#
COMPILE_LIBGCRYPT='n'
read -p "Do you want to compile libgcrypt? (y/n): " COMPILE_LIBGCRYPT
case $COMPILE_LIBGCRYPT in
    'n'|'N')
        COMPILE_LIBGCRYPT='n';;
    'y'|'Y')
        COMPILE_LIBGCRYPT='y';;
esac

IPTABLES_SETUP='n'
read -p "Do you want to set up IPTABLES rults for the shard server (one-time setup)? (y/n): " IPTABLES_SETUP
case $COMPILE_LIBGCRYPT in
    'n'|'N')
        COMPILE_LIBGCRYPT='n';;
    'y'|'Y')
        COMPILE_LIBGCRYPT='y';;
esac

################################################################################

echo "==================================================================="
echo "Updating and upgrading aptitude... this can take a long time if your"
echo "internet connection is slow"
#apt-get update && apt-get upgrade

echo "==================================================================="
if [    "${INSTALL_BASICS}" = "y" ]; then
    # basics:
    if [ ! -d /root/noarch ]; then
        mkdir -p /root/noarch
    fi
    cd /root/noarch


    install_it debian-keyring

    # for pscopg 2.6.1
    gpg --keyserver pgp.mit.edu --recv-keys 6013BD3AFCF957DE
    gpg --armor --export 6013BD3AFCF957DE| apt-key add -

    # for linode
    gpg --keyserver pgp.mit.edu --recv-keys C697D823EB0AB654
    gpg --armor --export C697D823EB0AB654| apt-key add -




    install_it vim 
    install_it nano
    install_it lynx 
    install_it screen 
    install_it rsync 
    install_it curl wget   # needed for installs
    install_it fail2ban 

    install_it iptables
		install_it iptables-persistent

    # apps needed to install and compile the Natural Message server 
    # verification C programs.
    install_it gcc 
    install_it make 
    echo "bzip2 (bz2) with C headers is needed for the libgcrypt install."
    #install_it bzip2-devel
    apt-get source bzip2 
    #
    # for the pythong command-line client, needed for testing the servers
    install_it unrtf
    #
    # Devel headers needed for pyOpenssl to tet TLS_1_2
    #install_it openssl
    install_it dpkg-dev 
    apt-get source openssl 
    #
    # install_it lib${ARCHBITS}ncurses5-dev

    install_it zlib1g-dev 

    apt-get source lib${ARCHBITS}ncurses5-dev 
    apt-get source sqlite3 

    apt-get source readline 

    apt-get source libpcap 

    apt-get source xz-utils 
fi

################################################################################
############################################################
natmsg_tst=$(cat /etc/passwd|grep '^natmsg[:]')
if [ -z "${natmsg_tst}" ]; then
    # The natmsg user ID does not exist, create it and set the password.
    useradd --create-home     -s /bin/bash natmsg 

    # give it root privileges
    echo "super ALL=(ALL:ALL) ALL" > /etc/sudoers.d/natmsg
    echo "natmsg ALL=(ALL:ALL) ALL" >> /etc/sudoers.d/natmsg
    chmod 600 /etc/sudoers.d/natmsg

    echo " "
    echo " "
    echo "You will now be prompted to enter a password for the natmsg"
    echo "user ID.    Use a good password because hackers will know that"
    echo "you have a natmsg user ID and might try to crack the password."
    read -p '...' junk
    set_pw natmsg
fi

if [ ! -d /home/natmsg ]; then
    mkdir /home/natmsg
    chown natmsg:natmsg /home/natmsg
fi

if [ ! -f /home/natmsg/.vimrc ]; then
    cp /root/.vimrc /home/natmsg/.vimrc
    chown natmsg:natmsg /home/natmsg/.vimrc
fi

if [ ! -f /home/natmsg/.profile ]; then
    cp /root/.profile /home/natmsg/.profile
    chown natmsg:natmsg /home/natmsg/.profile
fi

if [ ! -f /home/natmsg/.screenrc ]; then
    cat /root/.screenrc|sed -e 's/[.]bW/.gW/' > /home/natmsg/.screenrc
    chown natmsg:natmsg /home/natmsg/.screenrc
fi

if [ ! -d /var/natmsg ]; then
    mkdir /var/natmsg
fi
chown natmsg:natmsg /var/natmsg
chmod 755 /var/natmsg

if [ ! -d /var/natmsg/private ]; then
    mkdir /var/natmsg/private
fi
chown natmsg:natmsg /var/natmsg/private
chmod 700 /var/natmsg/private

if [ ! -d /var/natmsg/private/TestKeys ]; then
    mkdir /var/natmsg/private/TestKeys
fi
chown natmsg:natmsg /var/natmsg/private/TestKeys
chmod 700 /var/natmsg/private/TestKeys


if [ ! -d /var/natmsg/shards ]; then
    mkdir /var/natmsg/shards
fi
chown natmsg:natmsg /var/natmsg/shards
chmod 700 /var/natmsg/shards

if [ ! -d /var/natmsg/html ]; then
    mkdir /var/natmsg/html
fi
chown natmsg:natmsg /var/natmsg/html
chmod 500 /var/natmsg/html

if [ ! -d /var/natmsg/html/img ]; then
    mkdir /var/natmsg/html/img
fi
chown natmsg:natmsg /var/natmsg/html
chmod 500 /var/natmsg/html

if [ ! -d /var/natmsg/conf ]; then
    mkdir /var/natmsg/conf
fi
chown natmsg:natmsg /var/natmsg/conf
chmod 700 /var/natmsg/conf

if [ ! -d /var/natmsg/webmaster ]; then
    mkdir /var/natmsg/webmaster
fi
chown natmsg:natmsg /var/natmsg/webmaster
chmod 700 /var/natmsg/webmaster

if [ ! -d /var/natmsg/.gnupg ]; then
    mkdir /var/natmsg/.gnupg
fi
chown natmsg:natmsg /var/natmsg/.gnupg
chmod 700 /var/natmsg/.gnupg


if [ ! -d /var/natmsg/shards/a ]; then
    # Shards for each day of the week go on a different
    # subdirectory
    mkdir -p /var/natmsg/shards/a
    mkdir -p /var/natmsg/shards/b
    mkdir -p /var/natmsg/shards/c
    mkdir -p /var/natmsg/shards/d
    mkdir -p /var/natmsg/shards/e
    mkdir -p /var/natmsg/shards/f
    mkdir -p /var/natmsg/shards/g
    chown -R natmsg:natmsg /var/natmsg/shards
    chmod -R 700 /var/natmsg/shards/
fi


## # # Install some fake server keys for quick testing.
## # if [ ! -f "/var/natmsg/private/TestKeys/JUNKTESTOfflinePUBSignKey.key" ]; then
## #     # The sql file is not in the permanent place..
## #     tst_file="${SOURCE_DIR}/private/TestKeys/JUNKTESTOfflinePUBSignKey.key"
## #     if [ -f "${tst_file}" ]; then
## #         # Copy the sql from the untarred github directory
## #         echo "Copying SQL from ${SOURCE_DIR}"
## #         cp -r "${SOURCE_DIR}/private/TestKeys" /var/natmsg/private
## #         chmod 700 /var/natmsg/private
## #         chown -R natmsg:natmsg /var/natmsg/private
## #     else
## #         echo "Error. I can not find the source test keys. They should be in"
## #         echo "the sql subdirectory in the github file (under ${SOURCE_DIR})."
## #         echo "Test file was ${tst_file}"
## #         exit 493
## #     fi
## # fi




# ntpdate will disappear, but it works for now
install_it ntpdate 
# sync the time
ntpdate 2.fedora.pool.ntp.org

chown -R natmsg:natmsg /var/natmsg
# # # # # # # ## # #
#
# mail setup
touch    /var/mail/natmsg
chown natmsg:natmsg /var/mail/natmsg 

############################################################
########################################################################
# Python 3 from source seems to be needed for Debian 7 because
# the builtin _ssl lib did not have TLS_1_2.
#
echo "Installing/updating python3-dev..."
install_it python3-dev 
echo "Installing/updating python3-openssl..."
install_it python3-openssl 
### read -p "Do you want to install Python3 from source? (y/n): " MENU_CHOICE
### case $MENU_CHOICE in
###     'n'|'N')
###         MENU_CHOICE='n';;
###     'y'|'Y')
###         MENU_CHOICE='y';;
### esac
### 
### if [ "${MENU_CHOICE}" = "y" ]; then
###     ###
###     ###
###     ###
###     if [ ! -d /root/noarch ]; then
###         mkdir -p /root/noarch
###     fi
###     cd /root/noarch
###     if [    -f Python-${PYTHON_VER}.tgz ]; then
###         read -p "The Python 3 source file already exists.    Do you want to " \
###             "KEEP that version? " MENU_CHOICE
###         case $MENU_CHOICE in
###             'n'|'N')
###                 MENU_CHOICE='n';;
###             'y'|'Y')
###                 MENU_CHOICE='y';;
###         esac
###         
###         if [    "${MENU_CHOICE}" = "n" ]; then
###             rm Python-${PYTHON_VER}.tgz
###         fi
###     fi
### 
###     if [ ! -f Python-${PYTHON_VER}.tgz ]; then
###         # The Python file is not already here, so download it...
###         wget https://www.python.org/ftp/python/${PYTHON_VER}/Python-${PYTHON_VER}.tgz
###         tar xf Python-${PYTHON_VER}.tgz
###     fi
### 
###     if [    -d Python-${PYTHON_VER} ]; then
###         cd Python-${PYTHON_VER}
###     else
###         echo "ERROR, the Python directory was not found."
###         exit 123
###     fi
###     
###     ./configure --prefix=/usr/local --enable-shared
###     make
###     make install
###     # A python3 library is not in the default path,
###     # so add it like this:
###     # The ld.so.conf.d trick works on Centos 7, not sure about Debian 7.
###     echo /usr/local/lib >> /etc/ld.so.conf.d/local.conf
###     ldconfig
### fi

############################################################

################################################################################

if [    "${INSTALL_PYSETUP}" = "y" ]; then

    echo "Installing setuptools (ez_setup) from source"
    echo "(I originally installed from source because CentOS 7"
    echo "did not have an RPM for it)."
    if [ ! -d /root/noarch ]; then
      mkdir -p /root/noarch
    fi
    cd /root/noarch
    curl -L   --max-time 900 --retry 5 --retry-delay 60   --url https://bootstrap.pypa.io/ez_setup.py -O
    ${PYTHON3_PGM} ez_setup.py
fi

################################################################################
############################################################
echo "I will now test for the existence of shard svr python programs."
echo "Don't worry about the message that naturalmsg_shard is missing."
chk_natmsg=$(ls /var/natmsg/naturalmsg_shard*| grep naturalmsg|head -n 1)

##if [ -z "${chk_natmsg}" ]; then
    # there are no versions of the shard server, so install it

    if [    "${INSTALL_SHARD_SVR}" = "y" ]; then
        echo "Downloading the shard server"

        if [ ! -d /root/noarch ]; then
            mkdir -p /root/noarch
        fi
        cd /root/noarch
	
	# If this is a rerun, just delete old files -- they might be half-assed downloads,
	# and I don't want to prompt the user.
	if [ -f natmsgshardbig.tar.gz ]; then
		rm natmsgshardbig.tar.gz
	fi
	if [ -f natmsgshardbig.tar ]; then
		rm natmsgshardbig.tar
	fi

                # The max-time and retries options are set to facilitate transfer
                # across a slow connection.
        curl -L --max-time 900 --retry 5 --retry-delay 60 \
            --url https://github.com/naturalmessage/natmsgshardbig/archive/master.tar.gz \
						-o natmsgshardbig.tar.gz

          if [ $? != 0 ]; then
            echo "Error, the download of the shard server python stuff failed."
            read -p "Press ENTER to continue or CTL-c to quit..." junk
        else
            gunzip natmsgshardbig.tar.gz
            tar -xf natmsgshardbig.tar
            if [ $? != 0 ]; then
                echo "Error. Failed to un-tar the shard server python stuff."
                read -p "Press ENTER to continue or CTL-c to quit..." junk
            else
                cd natmsgshardbig-master
                chown natmsg:natmsg *
                cp -nv * /var/natmsg
                #### shard_dir is not ready yet: cp -vR sql "${SHARD_DIR}"
                #### shard_dir is not ready yet: if [ ! -f "${SHARD_DIR}/sql/0002create_db.sh" ]; then
                #### shard_dir is not ready yet:     echo "Error.    I do not see the 0002create_db.sh file in the expected place"
                #### shard_dir is not ready yet:     echo "(${SHARD_DIR}/sql/0002create_db.sh)."
                #### shard_dir is not ready yet:     echo "This means that the Nat Msg database will not be set up properly."
                #### shard_dir is not ready yet:     read -p "Press ENTER to continue or CTL-c to quit..." junk
                #### shard_dir is not ready yet: fi
            fi
        fi
    fi
##fi
############################################################

############################################################
# Install Postgres after Python 3 
# (and its dependencies, especially openssl source) has been
# installed (so that the postgre-python stuff can be 
# installed now

if [ -f "${PGSQL_BIN}/pg_ctl" ]; then
    echo "Postgres appears to be installed"
    INSTALL_PSQL='N'
fi

if [    "${INSTALL_PSQL}" = "y" ]; then
    # Install PostgreSQL
    #
    ##yum -y install postgresql-server postgresql-libs    postgresql-contrib postgresql-plpython
    install_it postgresql-server-dev-all 
    install_it postgresql
    install_it postgresql-client 
    apt-get source postgresql-server-dev-all 
    install_it pgp # for verification of downloaded files.
    
    echo  ""
    echo "When prompted, enter the password for the postgres user ID"
    set_pw postgres
    
    echo ""
    echo ""
    echo ""
    echo ""
    echo "The Debian install of PostgreSQL will set the home directory"
    echo "for the postgres user ID to /var/lib/postgres, so I will"
    echo "put the SQL stuff for Natural Message there."
    echo ""
    echo "The default data directory for the PostgreSQL database using the Debian"
    echo "install_it is:"
    echo "   ${PGSQL_DATA}"
    echo "(Note that on my other setup the 'main' dir is called 'data'.)"
    echo ""
    
    ### read -p "Press ENTER to continue..." junk
    echo ""
    echo "If installed from apt-get, the command for db setup is:"
    echo "   whereis pg_ctl"
    echo "   sudo -u postgres ${PGSQL_BIN}/pg_ctl -D ${PGSQL_DATA} initdb"
    echo ""
    echo ""
    if [ -d "${PGSQL_DATA}"  ]; then
        # maybe also check for /var/lib/postgresql/9.4/main/postgresql.conf
        if [ ! -d "${PGSQL_DATA}/base" ]; then
            sudo -u postgres "${PGSQL_BIN}/pg_ctl" -D "${PGSQL_DATA}" initdb
        else
            echo "It looks like the database was already initalized in " \
                "/var/lib/pgsql/data"
        fi
    else
        echo "ERROR. there is no pg data directory in the expected place: " \
            "${PGSQL_DATA}" 
        read -p "..." junk
    fi
    
    #-------------------------------------
    # one-time setup for postgres because it often
    # complains about permissions
    if [ ! -d  "${PGUSER_HOME}/shardsvr" ]; then
        mkdir -p "${PGUSER_HOME}/dirsvr"
        mkdir -p "${PGUSER_HOME}/functions"
        mkdir -p "${PGUSER_HOME}/shardsvr"
        mkdir -p "${PGUSER_HOME}/sysmon"
    fi
    chown -R postgres:postgres "${PGUSER_HOME}"
    chmod -R 700 "${PGUSER_HOME}"
    
    
    # start the server prefferably running in 'screen'
    # declare -i chk_pg
    chk_pg=$(ps -A|grep postgres|wc -l|tr -d ' ')
    ##if [ ${chk_pg} > 4 ]; then
    if [ "${chk_pg}" != "0" ]; then
        echo "postgreSQL is already running (${chk_pg})"
    else
        echo "Starting the PostgreSQL database now"
        ### Note: postgres on Debian ran upon install with this command 
        ###(from ps -Af|less)
        ## "${PGSQL_BIN}/postgres" -D "${PGSQL_DATA}" -c config_file="${PGSQL_CONF}"
        cd "${PGUSER_HOME}"
        sudo -u postgres "${PGSQL_BIN}/postgres" -D "${PGSQL_DATA}"  > "${LOG_FNAME}" 2>&1 &
    fi
    
    
    ### echo "This will attempt to edit the config file: ${PGSQL_CONF}"
    ### echo "file and set the listen addres to the current IP"
    ### echo "the ifconfig trick will not work on the default CentOS 7"
    MY_IP=$(ifconfig ${iface}|grep "inet add"|grep -v 127[.]0[.]0[.]1|tr -s ' '|cut -d ' ' -f 3|cut -d ':' -f 2)
    
    
    #make a backup of the config
    
    DSTAMP=`date +"%Y%m%d%H%M%S"`
    ############################################################
    # Install psycopg2 for python3 (postgres interface for python)
    # Because I installed python from source, I think I need
    # to install psycopg2 from source or Debian will install
    # the wrong version of python as a dependency
    # and then put psycopg2 there.
    
    if [ ! -d /root/noarch ]; then
        mkdir -p /root/noarch
    fi
    cd /root/noarch
    ## wget https://pypi.python.org/packages/source/p/psycopg2/psycopg2-${PSYCOPG_VER}.tar.gz
    curl -L --url https://pypi.python.org/packages/source/p/psycopg2/psycopg2-${PSYCOPG_VER}.tar.gz -O

    ##wget https://pypi.python.org/packages/source/p/psycopg2/psycopg2-${PSYCOPG_VER}.tar.gz.asc # sig
    curl -L --url https://pypi.python.org/packages/source/p/psycopg2/psycopg2-${PSYCOPG_VER}.tar.gz.asc -O # sig
    
    ### md5_check=$(openssl dgst -md5 psycopg2-2.5.4.tar.gz|cut -d ' ' -f 2)
    ### if [    "${md5_check}" = "25216543a707eb33fd83aa8efb6e3f26" ]; then
    ###     echo "good md5"
    ### else
    ###     echo "BAD MD5 for psycopg"
    ###     read -p "..." junk
    ### fi
    
    # Verify PGP signature.  Requires the apt-key add command at the top
    # to fetch the particular key that signed this
    gpg --verify psycopg2-${PSYCOPG_VER}.tar.gz.asc psycopg2-${PSYCOPG_VER}.tar.gz
    

  cd /root/noarch
  install_it libpqxx3-dev 
  gunzip psycopg2-${PSYCOPG_VER}.tar.gz 
  tar -xf psycopg2-${PSYCOPG_VER}.tar 
  cd /root/noarch/psycopg2-${PSYCOPG_VER}

  echo "my directory is `pwd`" 

  # You must run the correct python3 executable.  There might
  # be an old verion in /usr/bin.
  "${PYTHON3_PGM}" ./setup.py install 
  if [ $? != 0 ]; then
    echo "Failed to install psycopg2, which is required for CherryPy to access the database."
    exit 8478
  fi
    
fi
# end of postgres install

############################################################
############################################################
############################################################
############################################################
# see if cherrypy is installed
${PYTHON3_PGM} -c 'import cherrypy'

if [ $? = 0 ]; then
    echo "Cherrypy is installed"
else
    echo "Cherrypy is not installed.  Installing now."
    # Debian 8 has a package for python3-cherrypy3 that should
    # simplify the install.  The old Debian 7 installed from source.
  install_it python3-cherrypy3 
    #
    #
fi

################################################################################
################################################################################
# I will ship this ## RNCryptor - encryption package used by the client app.
# I will ship this ## also used for PBKDF2 for password-strengthening
# I will ship this #cd /var/natmsg
# I will ship this #curl -L --url https://github.com/RNCryptor/RNCryptor-python/raw/master/RNCryptor.py > /var/natmsg/RNCryptor.py
# I will ship this #chmod 644 RNCryptor.py

${PYTHON3_PGM} -c 'import Crypto'

if [ $? = 0 ]; then
    echo "The python Crypto library is already installed."
else
    echo "The python Crypto library is NOT installed... Installing it now."



    # RNCryptor requires the Crypto python library, which
    # is described here: https://www.dlitz.net/software/pycrypto/doc/
    if [ ! -d /root/noarch ] ; then
        mkdir -p /root/noarch
    fi
    cd /root/noarch
    
    curl -L --url https://ftp.dlitz.net/pub/dlitz/crypto/pycrypto/pycrypto-${PSYCOPG_VER}.tar.gz > /root/noarch/pycrypto.tar.gz
    
    cd /root/noarch
    gunzip /root/noarch/pycrypto.tar.gz
    tar -xf /root/noarch/pycrypto.tar
    crypto_dir=$(ls -d pycrypto-* |sort -r|head -n 1)
    cd "${crypto_dir}"
    ${PYTHON3_PGM} setup.py install
    if [ $? != 0 ]; then
        echo "Failed to build the Crypto library (do you have python.h from the python3-dev package?)"
      exit 8473
    fi
fi

###############################################################################


#                                                            OpenSSL for CherryPy
## The SSL certs can not have a password, so put them
## in an ecryptfs directory

# install libffi with headers:
install_it libffi-dev 

install_it python3-openssl 
#
# This is the old debian 7 routine:
## ##  # The built-in version of the python ssl lib in Debian7 did not have tls 1.2
## ##  #
## ##  
## ##  # openssl for cherrypy (note tested)
## ##  # For openssl, first download pyopenssl 
## ##  # from https://github.com/pyca/pyopenssl/archive/master.zip
## ##  cd /root/noarch
## ##  curl -L --url https://github.com/pyca/pyopenssl/archive/master.zip > pyopenssl.zip
## ##  
## ##  unzip pyopenssl.zip
## ##  if [    -d pyopenssl-master ]; then
## ##      cd pyopenssl-master
## ##  else
## ##      echo "Error. The pyopenssl-master directory does not exist"
## ##  fi
## ##  /usr/local/bin/python3 setup.py install --user
## ##  
## ##  # PyOpenSSL is not enough.  I need to compile _ssl, used by 
## ##  # https://hg.python.org/cpython/file/default/Lib/ssl.py 
## ##      #
## ##  #
## ##  # my install on CentOS7 went to 
## ##  #     /opt/python3/lib/python3.4/site-packages/pyOpenSSL-0.14-py3.4.egg
## ##  #

########################################################################
########################################################################

############################################################
## The Requests lib for python comes from
## http://docs.python-requests.org/en/latest/user/install/#get-the-code
## and the downloaded directory looks something like this:
## kennethreitz-requests-359659c
##
## This was installed from source in Debian 7, now there is a package:

install_it python3-requests
#### old debian 7 version
### if [  "${MENU_CHOICE}" = "y" ]; then
###   cd /root/noarch
###   if [ ! -f requests-master.tar.gz ]; then
###     curl -L \
###             --url https://github.com/kennethreitz/requests/tarball/master > requests-master.tar.gz
###   fi
### 
###   if [ ! -f requests-master.tar ]; then
###    gunzip requests-master.tar.gz
###   fi
### 
###   tar -xf requests-master.tar
### 
###   ##cd kennethreitz-requests-122c92e
###   dir_name=$(ls -lotrd kennethreitz-requests* |tail -n 1|cut -d ' ' -f 9)
###   cd "${dir_name}"
### 
###   # Be sure to execute the correct version of python3
###   /usr/local/bin/python3 setup.py install
### fi



############################################################
# install libgcrypt and dependencies from source because
# Debian 8 does not have gpg 2.1 packages.
# GPG is used by nm_verify.
#
# BE CAREFUL TO NOT INSTALL THE DEFAULT PINENTRY--IT WILL INSTALL GUI
# here is a list of current downloads from a mirror in Canada:
# http://gnupg.parentinginformed.com/download/index.html#libgpg-error
##

if [    "${INSTALL_GPG_ERROR}" = "y" ]; then
    if [ ! -d /root/c/lib ]; then
        mkdir -p /root/c/lib
    fi

    cd /root/c/lib
    ######        
    if [    -f ${LIBGPGERR_VER}.tar.bz2 ]; then
        read -p "The libgpg-error    source file already exists.    Do you want " \
            "to DELETE that version? " MENU_CHOICE
        case $MENU_CHOICE in
            'n'|'N')
                MENU_CHOICE='n';;
            'y'|'Y')
                MENU_CHOICE='y';;
        esac

        if [    "${MENU_CHOICE}" = "y" ]; then
            rm ${LIBGPGERR_VER}.tar.bz2
        fi
    fi

    if [ ! -f ${LIBGPGERR_VER} ]; then
        ##wget ftp ftp://ftp.gnupg.org/gcrypt/libgpg-error/${LIBGPGERR_VER}.tar.bz2
#### FIX THIS
#### FIX THIS
#### FIX THIS
#### FIX THIS
#### FIX THIS
#### FIX THIS
        curl -L --url ftp://ftp.gnupg.org/gcrypt/libgpg-error/${LIBGPGERR_VER}.tar.bz2 -O

        ##wget ftp://ftp.gnupg.org/gcrypt/libgpg-error/${LIBGPGERR_VER}.tar.bz2.sig
        curl -L --url ftp://ftp.gnupg.org/gcrypt/libgpg-error/${LIBGPGERR_VER}.tar.bz2.sig -O
    fi

    if [    -d ${LIBGPGERR_VER} ]; then
        echo "The libgpgerr directory already exists.     I will rename it."
        mv ${LIBGPGERR_VER} ${LIBGPGERR_VER}${DSTAMP}
    fi

    if [    -f ${LIBGPGERR_VER}.tar ]; then
        echo "The libgpgerr tar file already exists.     I will rename it."
        mv ${LIBGPGERR_VER}.tar ${LIBGPGERR_VER}.tar.${DSTAMP}
    fi

    if ! bunzip2 "${LIBGPGERR_VER}.tar.bz2"; then
        echo "Error, failed to unzip the ${LIBGPGERR_VER}.tar.bz2"
    else
        tar -xf "${LIBGPGERR_VER}.tar"

        cd "${LIBGPGERR_VER}" 
        if  ! ./configure --enable-static --disable-shared --prefix=/usr/local; then
            echo "Error. failed to configure ${LIBGPGERR_VER}"
            exit 12
        else
            # the static lib is lib/libgpg-error/src/.libs/libgpg-error.a
            if  ! make ; then
                echo "Error. Failed to make libgpg-error, which is needed for libgcrypt"
                exit 144
            else
                if  ! make install; then
                    echo "Error. Failed to install libgpg-error, which is needed " \
                        "for libgcrypt"
                    exit 145
                fi
            fi
        fi
    fi
fi #end of gpg-error install

########################################################################

if [    "${COMPILE_LIBGCRYPT}" = "y" ]; then
    if [ ! -d /root/c/lib ]; then
        mkdir -p /root/c/lib
    fi

    cd /root/c/lib
    if [    -f ${LIBGCRYPT_VER}.tar.bz2 ]; then
        read -p "The libgcrypt source file already exists.    Do you want to " \
            "DELETE that version? " MENU_CHOICE
        case $MENU_CHOICE in
            'n'|'N')
                MENU_CHOICE='n';;
            'y'|'Y')
                MENU_CHOICE='y';;
        esac

        if [    "${MENU_CHOICE}" = "y" ]; then
            rm ${LIBGCRYPT_VER}.tar.bz2
        fi
    fi

    if [ ! -f ${LIBGCRYPT_VER}.tar.bz2 ]; then
        ##wget ftp://ftp.gnupg.org/gcrypt/libgcrypt/${LIBGCRYPT_VER}.tar.bz2
        curl -L --url ftp://ftp.gnupg.org/gcrypt/libgcrypt/${LIBGCRYPT_VER}.tar.bz2 -O

        ##wget ftp://ftp.gnupg.org/gcrypt/libgcrypt/${LIBGCRYPT_VER}.tar.bz2.sig
        curl -L --url ftp://ftp.gnupg.org/gcrypt/libgcrypt/${LIBGCRYPT_VER}.tar.bz2.sig -O
    fi

    if [    -d ${LIBGCRYPT_VER} ]; then
        echo "The libgcrypt directory already exists.     I will rename it."
        mv ${LIBGCRYPT_VER} ${LIBGCRYPT_VER}${DSTAMP}
    fi

    if [    -f ${LIBGCRYPT_VER}.tar ]; then
        echo "The libgcrypt tar file already exists.     I will rename it."
        mv ${LIBGCRYPT_VER}.tar ${LIBGCRYPT_VER}.tar.${DSTAMP}
    fi

    if    ! bunzip2 ${LIBGCRYPT_VER}.tar.bz2; then
        echo "Error.    Failed to unzip libgcrypt."
        exit 133
    fi

    tar -xf ${LIBGCRYPT_VER}.tar
    cd ${LIBGCRYPT_VER}
    ## This needs to read the static version of libgpg-error to
    ## avoid confusion with the older version that might be in CentOS 7.
    ## The static library for libgpg-error is in 
    ## /root/c/lib/${LIBGPGERR_VER}/src/.libs/libgpg-error.a

    # try to point to static lib
    export GPG_ERROR_LIBS=/root/c/lib/${LIBGPGERR_VER}/src/.libs/
    ./configure --enable-static --disable-shared \
        --with-libgpg-error-prefix=/usr/local --prefix=/usr/local

    # The static library made by make with the static option is:
    #    lib/libksba/src/.libs/libksba.a
    if [ ! make ]; then
        echo "Error.    Failed to make libgcrypt."
        exit 135
    fi
    if  ! make install; then
        echo "Error.    Failed to run make install libgcrypt."
        exit 137
    fi
fi


if [ -f /root/c/lib/${LIBGCRYPT_VER}/src/.libs/libgcrypt.a ]; then
    # this might not be necessary now that I run the install above
    install -t /usr/local/lib  /root/c/lib/${LIBGCRYPT_VER}/src/.libs/libgcrypt.a
    ###chown root:root /usr/local/bin/libgcrypt.*
    chown root:root /usr/local/lib/libgcrypt.*
    echo "I now have a static library for libgcrypt that can "
    echo "be compiled into my other programs"
else
    echo "Error.    I did not find the static library for libgcrypt"
    echo "that can be compiled into my other programs"
    read -p "Press ENTER to continue..." junk
fi


################################################################################
################################################################################

# gpg agent (for the future mix network)
if [ ! -f ~/.profile ]; then
cat >> ~/.profile <<EOF
agent_check=$(ps -A|grep " gpg[-]agent$")
if [    -z "${agent_check}" ]; then
     gpg-agent --daemon --enable-ssh-support \
     --write-env-file "${HOME}/.gpg-agent-info"
fi
if [ -f "${HOME}/.gpg-agent-info" ]; then
             . "${HOME}/.gpg-agent-info"
             export GPG_AGENT_INFO
             export SSH_AUTH_SOCK
fi

# To top GNU screen from changing the named
# screens after every command, combined with
# 'shelltitle "%t%" in .screenrc
# You have to manually run this command INSIDE
# a GNU screen screen to stop the window title from changing.
PROMPT_COMMAND='printf "\033k\033\134"'
EOF
fi

if [ ! -f /root/.vimrc ]; then
cat <<EOF > /root/.vimrc
" The ic option is for case insenstive search:
set ic
if &t_Co > 2 || has("gui_running")
    syntax on
    set hlsearch
        " set font for GUI
        set gfn=Monospace\ 14
endif

set wrap
" line break
set ruler
set showcmd

" shiftwidth controls indentation when
" shiftwidth controls indentation when
" the user prcesses the > character.
set shiftwidth=2

" tabstop is the width of the tab character.
set tabstop=2
EOF
fi


if [ ! -f /root/.screenrc ]; then
cat <<EOF > /root/.screenrc
shelltitle "zz%t%"
hardstatus on
hardstatus alwayslastline
hardstatus string "%{.bW}%-w%{.rW}%n %t%{-}%+w %=%{..G} %H %{..Y} %m/%d %C%a "
#hardstatus string "%t%"
# Some codes from the man page for screen:
# The attribute set can either be specified as a hexadecimal number or a combination of the following letters:
# d=dim , u=underline , b=bold , r=reverse , s=standout , B=blinking
# 
# Colors:
# k=black , r=red , g=green , y=yellow , b=blue , m=magenta , c=cyan , w=white , d=default color , .=leave color unchanged 
EOF
fi
############################################################
rslt=$(crontab -l|grep monitor.py)
    if [    -z "${rslt}" ]; then
    echo "============================================================"
    echo "Attempting to set a cron job that run under the root ID"
    echo "and runs /var/natmsg/monitor.py every 5 minutes."
    echo

    echo "*/5 * * * * /usr/bin/python3.4 /var/natmsg/monitor.py" > /var/spool/cron/crontabs/root
    chmod 600 /var/spool/cron/crontabs/root
fi
############################################################

################################################################################
################################################################################
cd /root/noarch
if [ -f natmsgv.tar.gz ]; then
    rm natmsgv.tar.gz
fi
if [ -f natmsgv.tar ]; then
    rm natmsgv.tar
fi

##wget https://github.com/naturalmessage/natmsgv/archive/master.tar.gz -O natmsgv.tar.gz
##curl -L --url https://github.com/naturalmessage/natmsgv/archive/master.tar.gz -O natmsgv.tar.gz -O
### FIX THE LINE ABOVE
### FIX THE LINE ABOVE
### FIX THE LINE ABOVE
### FIX THE LINE ABOVE
### FIX THE LINE ABOVE
### FIX THE LINE ABOVE
### FIX THE LINE ABOVE
### FIX THE LINE ABOVE
### FIX THE LINE ABOVE
### FIX THE LINE ABOVE
### FIX THE LINE ABOVE
### FIX THE LINE ABOVE
### FIX THE LINE ABOVE
### FIX THE LINE ABOVE
### FIX THE LINE ABOVE
### FIX THE LINE ABOVE
### FIX THE LINE ABOVE
### FIX THE LINE ABOVE
### FIX THE LINE ABOVE
### FIX THE LINE ABOVE
### FIX THE LINE ABOVE
curl -L \
	--url https://github.com/naturalmessage/natmsgv/archive/master.tar.gz \
	-o natmsgv.tar.gz
if [ $? != 0 ]; then
    echo "Error.  Failed to get the natmsg verification installation file."
    read -p "Press any key to continue ..." junk
else
    gunzip natmsgv.tar.gz
    tar -xf natmsgv.tar
    if [ $? != 0 ]; then
        echo "Error.  Failed to un-tar the natmsg verification installation file."
        read -p "Press any key to continue ..." junk
    else
        cd natmsgv-master
        make

        if [ $? != 0 ]; then
            echo "Failed to make natmsgv (server verification C program" | tee -a "${LOG_FNAME}"
				else
            echo "Successfully ran make natmsgv (server verification C program" | tee -a "${LOG_FNAME}"
        fi
        cp -nv nm_* /var/natmsg
        chown natmsg:natmsg /var/natmsg/nm_*
    fi
fi
################################################################################
############################################################
############################################################
############################################################
#############################################################
clear
echo "================= The first part of the installation is finished." | tee -a "${LOG_FNAME}"
echo "The next (final) step will install files unique to "
echo "the shard server (as opposed to the directory server)."

if grep '^postgres[:]' /etc/passwd; then
    # The postgres user exists. Create some directories.
    if [ ! -d "${SHARD_DIR}/sql" ]; then
        mkdir -p "${SHARD_DIR}/sql"
    fi

    chown -R postgres:postgres "${PGUSER_HOME}"
fi

echo "Source DIR is ${SOURCE_DIR}"

##if [ ! -s "${PGUSER_HOME}/shardsvr/sql/0010setup.sql" ]; then
##    # The sql file is not in the permanent place..
##    if [ -s "${SOURCE_DIR}/sql/0010setup.sql" ]; then
##        # Copy the sql from the untarred github directory
##        echo "Copying SQL from ${SOURCE_DIR}"
##        cp -r "${SOURCE_DIR}/sql" "${PGUSER_HOME}/shardsvr"
##    else
##        echo "Error. I can not find the source sql files. They should be in"
##        echo "the sql subdirectory in the github file."
##        exit 493
##    fi
##fi
echo "checkpoint bbb"
chown -R postgres:postgres "${PGUSER_HOME}"
#############################################################
# Start the database (if it is not running), then
# Create the database and build the tables.

if [ -d "${SHARD_DIR}/sql" ]; then

    cd "${SHARD_DIR}/sql"

    # start the server prefferably running in 'screen'
    # declare -i chk_pg
    chk_pg=$(ps -A|grep postgres|wc -l)
    echo "testing chk_pg: ${chk_pg}"
    if [ "${chk_pg}" != "0" ]; then
        echo "postgreSQL is already running"
    else
        echo "Starting the PostgreSQL database now"
        ### Note: postgres on Debian ran upon install with this command 
        ###(from ps -Af|less)
        ## "${PGSQL_BIN}/postgres" -D "${PGSQL_DATA}" -c config_file="${PGSQL_CONF}"
        cd "${PGUSER_HOME}"
        sudo -u postgres "${PGSQL_BIN}/postgres" -D "${PGSQL_DATA}" &
        if [ ! $? = 0 ]; then
            echo "Error.  Could not start the postgreSQL database."
            exit 87
        fi
    fi

    echo "I will now check for the existence of the shard server database:"

    cd ${SHARD_DIR}
    db_existence=$(sudo -u postgres psql  -c '\q' ${DBNAME})
    if [ $? = 0 ]; then
        echo "The shardsvrdb database exists"
    else
        echo "I did not find the shardsvrdb.  I will create it now"


        cd /root/noarch/natmsgshardbig-master
        cp -vR sql "${SHARD_DIR}"
        if [ ! -f "${SHARD_DIR}/sql/0002create_db.sh" ]; then
            echo "Error.    I do not see the 0002create_db.sh file in the expected place"
            echo "(${SHARD_DIR}/sql/0002create_db.sh)."
            echo "This means that the Nat Msg database will not be set up properly."
            read -p "Press ENTER to continue or CTL-c to quit..." junk
        fi

        cd "${SHARD_DIR}/sql"
        sudo -u postgres  ./0002create_db.sh
        echo "==== Finished 0002create_db.sh" | tee -a ${LOG_FNAME}
    fi

    cd "${SHARD_DIR}/sql"
    db_existence=$(sudo -u postgres psql -c '\q'  ${DBNAME})
    if [ $? != 0 ]; then
        echo "Error. Failed to create the shardsvrdb database." | tee -a ${LOG_FNAME}
        exit 834
    fi

    # Check if a table exists:
    chk_shard=$(sudo -u postgres psql \
        -c '\d shardsvr.big_shards' ${DBNAME} |grep big_shard_pkid|tail -n 1)

    # sudo -u postgres psql -c '\d shardsvr.big_shards' ${DBNAME} |grep big_shard_pkid|tail -n 1

    if [ -z "${chk_shard}" ]; then
        clear
      echo "I do not see a shard table, so I will install the shard tables."
      ###     if [ -f "${SHARD_DIR}/sql/0002create_db.sql" ]; then
      ###         cd "${SHARD_DIR}/sql"
      ###         sudo -u postgres psql  -c "\i 0002create_tables.sql" "${DBNAME}"
      ###     fi
      ### 
      ### # 
        # Get a password to initialize the database, save it in 0010once.sql
        ##read -s -p "Enter a new password for the database: " NEW_DB_PW
        good_pw='n'
        while [ good_pw == 'n' ]; do
            read -p "Enter a new password for the database: " NEW_DB_PW
            cat "${SHARD_DIR}/sql/0010setup.sql"|sed \
                -e "s/ENTER_YOUR_database_PASSWORD/${NEW_DB_PW}/" > \
                "${SHARD_DIR}/sql/0010once.sql"
            
            cat "${SHARD_DIR}/sql/0010once.sql"|grep pass
            echo "Check the line above. If you alread have the database password " \
                "in 0010setup.sql"
            if confirm "Do you want to use that password? (y/n): "; then
                echo "OK, I will now try to create the database..." | tee -a ${LOG_FNAME}
                good_pw='y'
            fi
        done

        cd "${SHARD_DIR}/sql"
        sql_it 0010once.sql "${DBNAME}"
        sql_it 0015shard_server.sql "${DBNAME}"
        sql_it 0016shard_server_big.sql "${DBNAME}"
        sql_it functions/scan_shard_delete.sql "${DBNAME}"
        sql_it functions/shard_burn.sql "${DBNAME}"
        sql_it functions/shard_delete.sql "${DBNAME}"
        sql_it functions/shard_expire.sql "${DBNAME}"
        sql_it functions/sysmon010.sql "${DBNAME}"
        sql_it functions/shard_burn_big.sql "${DBNAME}"
        sql_it functions/shard_delete_db_entries.sql "${DBNAME}"
        sql_it functions/shard_expire_big.sql "${DBNAME}"
        sql_it functions/shard_id_exists.sql "${DBNAME}"

        #shred -u 0010once  #remove the temp file with pw
    else
        echo "I am not installing the shard server tables because I already " \
            "found a shard table." | tee -a ${LOG_FNAME}
    fi
else
    echo "=========== The shard directory was not found: ${SHARD_DIR}/sql."
    echo "If you were trying to install the shard server, you have to choose"
    echo "the option to install the NatMsg shard server before the install/configure"
    echo "step will run properly.  Try running this script again with the option"
    echo "to install the Nat Msg shard server."
    read -p echo "press ENTER to continue..." junk
fi
############################################################
############################################################
if [ "${IPTABLES_SETUP}" = 'y' ]; then
    echo "====================== here are the old firewall rules before flushing and re-initializing:"
    iptables --list
    iptables --list-rules

    # clear 
    iptables --flush

    ### optionally insert a rule early in the chain to allow your ip
    ##iptables -I INPUT -s 123.123.123.0/24 -j ACCEPT

    # Allow established connections:
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    # ssh:
    iptables -A INPUT -m state --state new -m tcp -p tcp --dport 22 -j ACCEPT
    # postgre sql
    iptables -A INPUT -m state --state new -m tcp -p tcp --dport 5432 -j ACCEPT
    # https and https ports:
    iptables -A INPUT -m state --state new -m tcp -p tcp --dport 80 -j ACCEPT
    iptables -A INPUT -m state --state new -m tcp -p tcp --dport 443 -j ACCEPT

    # Erlang Connector for testing 
    iptables -A INPUT -m state --state new -m tcp -p tcp --dport 8443 -j ACCEPT
    # shard server ports:
    iptables -A INPUT -m state --state new -m tcp -p tcp --dport 4430:4440 -j ACCEPT

    # Erlang stuff.
    # the RPC setup for erlang.
    iptables -A INPUT -p tcp --dport 111 -j ACCEPT
    # I don't think I need to open 123 for the ntp/time
    # server because I query another server as opposed
    # to allowing somebody else to initialize a connection
    # to my port 123.
    #iptables -A INPUT -p udp --dport 123 -j ACCEPT
    ###############################################################################
    # The last iptables command is to APPEND a command to drop
    # all other incomming:
    # Default policy is to drop inbound action:
    iptables --policy INPUT DROP
    ###############################################################################
    ## Make the iptables settings permanent only after you know that
    ## they work and you can connect to your machine via ssh if you need to.
    iptables-save > /etc/iptables/rules.v4

    echo "====================== here are the NEW firewall rules:"
    iptables --list
    iptables --list-rules
fi

########################################################################


if [    "${INSTALL_SSC}" = "y" ]; then
    #
    # test it by running python3 and execute "from OpenSSL import SSL"
    #
    # Then create your ssl keys:
    # THESE FILES NEED TO BE ON AN ECRYPTFS DIRECTORY
    # THAT IS OWNED BY USER NATMSG.
    #     # 
    if [ ! -d /root/noarch/keytemp ]; then
        mkdir -p /root/noarch/keytemp
    fi
    chmod 700 /root/noarch/keytemp
    cd /root/noarch/keytemp
    # I previously got an error, but I ran it a few more times
    # and it was ok--or try fixing permissions on ~/.rnd:
    # error:0906906F:PEM routines:PEM_ASN1_write_bio:read key
    openssl genrsa -aes256 -out ca.key 2048
    # remove the password if need be (and store files on ecryptfs)
    openssl rsa -in ca.key -out ca.key
    openssl req -new -inform PEM -outform PEM -key ca.key -out ca.csr
    # For a real cert,
    # 1) send  ca.csr (Certificate Request) to the cert authority
    # 2) get ca.crt from the certificate authority and put it in
    #    /var/natmsg/private
    # 3) copy the ca.key that you created above to /var/natmsg/private
    # 4) If the cert provider gave you an additional or 'intermediate'
    #    cert, then save each cert in its own file for backup purposes,
    #    then include the intermediate cert at the bottom of the ca.crt
    #    file (calling it ca.crt)  
    # 5) fix the permissions in /var/natmsg/private:
    #     chown natmsg:natmsg /var/natmsg/private/*
    # 6) If the cert is new, verify the server.ssl_certificate filename
    #    in the appropriate conf file in /var/natmsg/conf
    # 7) backup the server  
         

    #Do the next openssl commands ONLY FOR SELF-SIGNED CERTIFICATE.
    # create the self-signed certificate
    echo "When the X509 certificate request is being created,"
    echo "you need to enter the correct domain name or IP in the"
    echo "Common Name field (do not include 'http://')"
    ##openssl x509 -req -inform PEM -outform PEM -days 63 \
    openssl x509 -req -inform PEM -outform PEM -days 400 \
        -in ca.csr -signkey ca.key -out ca.crt

    # You can run this to get information from your crt file:
    openssl x509 -text -in ca.crt # get info
    if [ ! -d "${CERT_KEY_ROOT}" ]; then
        mkdir -p "${CERT_KEY_ROOT}"
    fi
    chown -R natmsg:natmsg "${CERT_KEY_ROOT}"
    chmod 700 "${CERT_KEY_ROOT}"

    # Archive old keys before moving the new ones into place:
    if [ -f "${CERT_KEY_ROOT}/ca.key" ]; then
        # backup the old keys
        mv "${CERT_KEY_ROOT}/ca.key" "${CERT_KEY_ROOT}/${DSTAMP}.ca.key"
    fi

    if [ -f "${CERT_KEY_ROOT}/ca.csr" ]; then
        # backup the old keys
        mv "${CERT_KEY_ROOT}/ca.csr" "${CERT_KEY_ROOT}/${DSTAMP}.ca.csr"
    fi

    if [ -f "${CERT_KEY_ROOT}/ca.crt" ]; then
        # backup the old keys
        mv "${CERT_KEY_ROOT}/ca.crt" "${CERT_KEY_ROOT}/${DSTAMP}.ca.crt"
    fi

    cp -i /root/noarch/keytemp/ca.crt "${CERT_KEY_ROOT}"
    cp -i /root/noarch/keytemp/ca.key "${CERT_KEY_ROOT}"

fi

#Test ssl here (no IPs allowed at the first one): https://www.ssllabs.com/ssltest/
