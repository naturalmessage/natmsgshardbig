#!/bin/sh
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

##get_interfaces(){
##    # this is for Debian with the 'ip' program
##    ip_list=$(ip -o address|tr -s ' '|cut -d ' ' -f 2|uniq|grep -v lo)
##}
###############################################################################
apt-get install screen

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
PGSQL_BIN='/usr/lib/postgresql/9.1/bin/'
PGSQL_CONF='/etc/postgresql/9.1/main/postgresql.conf'
PYTHON_VER="3.4.3" # for source install only
PSYCOPG_VER="2.6" # version used in the download for psychopg2

LIBGCRYPT_VER="libgcrypt-1.6.3"
LIBGPGERR_VER="libgpg-error-1.19"
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
echo "PGSQL_BIN         ${PGSQL_BIN}"
echo "PGSQL_CONF        ${PGSQL_CONF}"
echo "LIBGCRYPT_VER     ${LIBGCRYPT_VER}"
echo "LIBGPGERR_VER     ${LIBGPGERR_VER}"
echo "ARCHBITS          ${ARCHBITS}"
echo "PYTHON_VER        ${PYTHON_VER}"
echo "PSYCOPG_VER       ${PSYCOPG_VER}"
echo "DSTAMP            ${DSTAMP}"
echo "initdb command :  sudo -u postgres ${PGSQL_BIN}/pg_ctl " \
    "-D ${PGSQL_DATA} initdb"
gshc_continue;


###############################################################################

apt-get upgrade

# basics:
if [ ! -d /root/noarch ]; then
    mkdir -p /root/noarch
fi
cd /root/noarch

apt-get install vim lynx screen rsync
apt-get install curl wget # needed for installs
apt-get install fail2ban

# apps needed to install and compile the Natural Message server 
# verification C programs.
apt-get install gcc
apt-get install make
echo "bzip2 (bz2) with C headers is needed for the libgcrypt install."
#apt-get install bzip2-devel
apt-get source bzip2
#
#
# Devel headers needed for pyOpenssl to tet TLS_1_2
#apt-get install openssl
apt-get install dpkg-dev
apt-get source openssl
#
# apt-get install lib${ARCHBITS}ncurses5-dev

apt-get install zlib1g-dev

apt-get source lib${ARCHBITS}ncurses5-dev
# apt-get install sqlite3
apt-get source sqlite3

#apt-get install readline
apt-get source readline

#apt-get install libpcap
apt-get source libpcap

# apt-get install xz-utils
apt-get source xz-utils

###############################################################################
natmsg_tst=$(cat /etc/passwd|grep '^natmsg[:]')
if [ -z "${natmsg_tst}" ]; then
    # The natmsg user ID does not exist, create it and set the password.
    if [ -f /bin/bash ]; then
        useradd --create-home     -s /bin/bash natmsg 
    else
        if [ -f /usr/local/bin/bash ]; then
            useradd --create-home     -s /usr/local/bin/bash natmsg 
        else
            echo "Error. Can not find the bash program to use as the " \
                "default shell for the natmsg user ID."
            echo "You should probably install bash and try again."
            exit 38
        fi
    fi
    echo " "
    echo " "
    echo "You will now be prompted to enter a password for the natmsg"
    echo "user ID.    Use a good password because hackers will know that"
    echo "you have a natmsg user ID and might try to crack the password."
    read -p '...' junk
    passwd natmsg
fi

if [ ! -d /home/natmsg ]; then
    mkdir /home/natmsg
    chown natmsg:natmsg /home/natmsg
fi


if [ ! -f /home/natmsg/.profile ]; then
    cp /root/.profile /home/natmsg/.profile
    chown natmsg:natmsg /home/natmsg/.profile
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


# Install some fake server keys for quick testing.
if [ ! -f "/var/natmsg/private/TestKeys/JUNKTESTOfflinePUBSignKey.key" ]; then
    # The sql file is not in the permanent place..
    tst_file="${SOURCE_DIR}/private/TestKeys/JUNKTESTOfflinePUBSignKey.key"
    if [ -f "${tst_file}" ]; then
        # Copy the sql from the untarred github directory
        echo "Copying SQL from ${SOURCE_DIR}"
        cp -r "${SOURCE_DIR}/private/TestKeys" /var/natmsg/private
        chmod 700 /var/natmsg/private
        chown -R natmsg:natmsg /var/natmsg/private
    else
        echo "Error. I can not find the source test keys. They should be in"
        echo "the sql subdirectory in the github file (under ${SOURCE_DIR})."
        echo "Test file was ${tst_file}"
        exit 493
    fi
fi


# ntpdate will disappear, but it works for now
apt-get install ntpdate
# sync the time
ntpdate 2.fedora.pool.ntp.org

chown -R natmsg:natmsg /var/natmsg
# # # # # # # ## # #
#
# mail setup
touch    /var/mail/natmsg
chown natmsg:natmsg /var/mail/natmsg 

if [ -z "${natmsg_tst}" ]; then
    echo "You will need to add the natmsg user ID to the sudoers list."
    echo "Run the visduo command from the root ID and replicate the"
    echo "    'root  ALL=(ALL:ALL) ALL' "
    echo "line and change root to natmsg."
    gshc_continue;
fi


###############################################################################
# Python 3 from source seems to be needed for Debian because
# the builtin _ssl lib did not have TLS_1_2.
#
if (gshc_confirm "Do you want to install Python3 from source? (y/n): " ); then
    if [ ! -d /root/noarch ]; then
        mkdir -p /root/noarch
    fi
    cd /root/noarch
    if [ -f Python-${PYTHON_VER}.tgz ]; then
        if (gshc_confirm "The Python 3 source file already exists.  " \
            "Do you want to DOWNLOAD THAT FILE AGAIN? (y/n): " ); then
            rm Python-${PYTHON_VER}.tgz
        fi
    fi

    if [ ! -f Python-${PYTHON_VER}.tgz ]; then
        # The Python file is not already here, so download it...
        wget https://www.python.org/ftp/python/${PYTHON_VER}/Python-${PYTHON_VER}.tgz
        tar xf Python-${PYTHON_VER}.tgz
    fi

    if [ -d Python-${PYTHON_VER} ]; then
        cd Python-${PYTHON_VER}
    else
        echo "ERROR, the Python directory was not found."
        exit 123
    fi
    
    ./configure --prefix=/usr/local --enable-shared
    make
    make install
    # A python3 library is not in the default path,
    # so add it like this:
    # The ld.so.conf.d trick works on Centos 7, not sure about Debian 7.
    echo /usr/local/lib >> /etc/ld.so.conf.d/local.conf
    ldconfig
fi

###############################################################################
if (gshc_confirm "Do you want to install Python setuptools " \
        "(needed to install other stuff)? (y/n): " ); then
    echo "Installing setuptools (ez_setup) from source"
    echo "Because Cent OS 7 does not have an RPM for it"
    if [ ! -d /root/noarch ]; then
      mkdir -p /root/noarch
    fi
    cd /root/noarch
    wget https://bootstrap.pypa.io/ez_setup.py
    python3 ez_setup.py
fi

###############################################################################
# Test if a natural message shard server program is already in the target
# directory.
chk_natmsg=$(ls /var/natmsg/naturalmsg_shard*| grep naturalmsg|head -n 1)
if [ -z "${chk_natmsg}" ]; then
    PRMPT="You already have at least one version of the natural message " \
        "shard server program.  Do you want to download and install a " \
        "fresh version of the the Natural Message shard server Python " \
        "code? (y/n): " 
else
    PRMPT="Do you want to download and install a fresh version " \
        "of the the Natural Message shard server Python code? (y/n): " 
fi

    # there are no versions of the shard server, so install it
if (gshc_confirm "${PRMPT}" ); then
    echo "Downloading the shard server"

    if [ ! -d /root/noarch ]; then
        mkdir -p /root/noarch
    fi
    cd /root/noarch

    curl -L --url https://github.com/naturalmessage/natmsgshardbig/archive/master.tar.gz > natmsgshardbig.tar.gz
    gunzip natmsgshardbig.tar.gz
    tar -xf natmsgshardbig.tar
    cd natmsgshardbig-master
    chown natmsg:natmsg *
    cp * /var/natmsg
fi
############################################################

############################################################
# Install Postgres after Python 3 
# (and its dependencies, especially openssl source) has been
# installed (so that the postgre-python stuff can be 
# installed now

if [ -f "${PGSQL_BIN}/pg_ctl" ]; then
    echo "Postgres appears to be installed"
    MENU_CHOICE='N'
else
    read -p "Do you want to install PostgreSQL? (y/n): " MENU_CHOICE
    case $MENU_CHOICE in
        'n'|'N')
            MENU_CHOICE='n';;
        'y'|'Y')
            MENU_CHOICE='y';;
    esac
fi

if [    "${MENU_CHOICE}" = "y" ]; then
    # Install PostgreSQL
    #
    apt-get install postgresql-server-dev-all
    apt-get install postgresql postgresql-client
    apt-get source postgresql-server-dev-all
    apt-get install pgp # for verification of downloaded files.
    
    echo  ""
    echo "When prompted, enter the password for the postgres user ID"
    passwd postgres
    
    echo ""
    echo ""
    echo ""
    echo ""
    echo "The Debian install of PostgreSQL will set the home directory"
    echo "for the postgres user ID to /var/lib/postgres, so I will"
    echo "put the SQL stuff for Natural Message there."
    echo ""
    echo "The default data directory for the PostgreSQL database using "
    echo "the Debian apt-get install is:"
    echo "   ${PGSQL_DATA}"
    echo "(Note that on my other setup the 'main' dir is called 'data'.)"
    echo ""
    gshc_continue;

    echo ""
    echo ""
    echo ""
    echo "If installed from apt-get, the command for db setup is:"
    echo "   whereis pg_ctl"
    echo "   sudo -u postgres ${PGSQL_BIN}/pg_ctl -D ${PGSQL_DATA} initdb"
    echo ""
    echo ""
    if [ -d "${PGSQL_DATA}"  ]; then
        # maybe also check for /var/lib/postgresql/9.1/main/postgresql.conf
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
        # ## Note: postgres on Debian ran upon install with this command 
        # ##(from ps -Af|less)
        # # "${PGSQL_BIN}/postgres" \
        # #     -D "${PGSQL_DATA}" -c config_file="${PGSQL_CONF}"
        cd "${PGUSER_HOME}"
        sudo -u postgres "${PGSQL_BIN}/postgres" \
            -D "${PGSQL_DATA}"  > logfile 2>&1 &
    fi
    
    
    ### echo "This will attempt to edit the config file: ${PGSQL_CONF}"
    ### echo "file and set the listen addres to the current IP"
    ### echo "the ifconfig trick will not work on the default CentOS 7"
    MY_IP=$(ifconfig ${iface}|grep "inet add"|grep -v 127[.]0[.]0[.]1|tr \
        -s ' '|cut -d ' ' -f 3|cut -d ':' -f 2)
    
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
    wget https://pypi.python.org/packages/source/p/psycopg2/psycopg2-${PSYCOPG_VER}.tar.gz
    wget https://pypi.python.org/packages/source/p/psycopg2/psycopg2-${PSYCOPG_VER}.tar.gz.asc # sig
    
    ### md5_check=$(openssl dgst -md5 psycopg2-2.5.4.tar.gz|cut -d ' ' -f 2)
    ### if [    "${md5_check}" = "25216543a707eb33fd83aa8efb6e3f26" ]; then
    ###     echo "good md5"
    ### else
    ###     echo "BAD MD5 for psycopg"
    ###     read -p "..." junk
    ### fi
    
    ### # PGP but I don't have the pubic key
    ### gpg --verify psycopg2-2.5.4.tar.gz.asc psycopg2-2.5.4.tar.gz
    
    # for libpq-fe.h, install the devel version of libpqxx
    apt-get install libpqxx3-dev
    gunzip psycopg2-2.5.4.tar.gz
    tar -xf psycopg2-2.5.4.tar
    cd psycopg2-2.5.4
    # You must run the correct python3 executable.  There might
    # be an old verion in /usr/bin.
    /usr/local/bin/python3 setup.py    install
    
fi
# end of postgres install

############################################################
############################################################
############################################################
############################################################
# see if cherrypy is installed
python3 -c 'import cherrypy'

if [ $? = 0 ]; then
    echo "Cherrypy is installed"
else
    echo "Cherrypy is not installed.  Installing now."
    # In Debian 8, this will change to python3-cherrypy3
    #
    #    CherryPi
    # Debian 8 will hav a package for python3-cherrypy3 that should
    # simplify the install.  This install will be from source.
    #
    # I need the mercurial VCS to get the source
    apt-get install mercurial 
    ############################################################
    ############################################################
    
    mkdir -p /root/noarch/CherryPySource
    cd /root/noarch/CherryPySource
    hg clone https://bitbucket.org/cherrypy/cherrypy
    cd cherrypy
    python3 setup.py install
fi

###############################################################################
# I will ship RNCryptor directly, so I do not need this RNCryptor stuff:
## RNCryptor - encryption package used by the client app.
# ## also used for PBKDF2 for password-strengthening
# #cd /var/natmsg
# #curl -L --url https://github.com/RNCryptor/RNCryptor-python/raw/master/RNCryptor.py > /var/natmsg/RNCryptor.py
# #chmod 644 RNCryptor.py

###############################################################################
python3 -c 'import Crypto'

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
    
    curl -L --url https://ftp.dlitz.net/pub/dlitz/crypto/pycrypto/pycrypto-2.6.1.tar.gz > /root/noarch/pycrypto.tar.gz
    
    cd /root/noarch
    gunzip /root/noarch/pycrypto.tar.gz
    tar -xf /root/noarch/pycrypto.tar
    crypto_dir=$(ls -d pycrypto-* |sort -r|head -n 1)
    cd "${crypto_dir}"
    python3 setup.py install
fi

###############################################################################


#                       OpenSSL for CherryPy
#
# The built-in version of the python ssl lib in Debian7 did not have tls 1.2
# Installing PyOpenSSL is not enough.  For Debian 7, you first need to
# install the openssl source so that the system has the right program,
# then after that is installed, comiling pyopenssl here will get the
# correct binaries.
#
# install libffi with headers:
apt-get install libffi-dev

#
# still needed ? # # The pyopenssl install seemed to mess up the 
#                # # cryptography package, which
# still needed ? # # is now trying to use libffi. so reinstall it
# still needed ? # # Download: https://github.com/pyca/cryptography/archive/master.zip
# still needed ? # cd /root/noarch
# still needed ? # curl -L --url https://github.com/pyca/cryptography/archive/master.zip > crypto.zip
# still needed ? # 
# still needed ? # unzip crypto.zip
# still needed ? # cd cryptography-master
# still needed ? # python3 setup.py install --user
#

PYO_DOWNLOAD="TRUE"
PYO_INSTALL="TRUE"
cd /root/noarch
if [ -f pyopenssl-master/setup.py ]; then
    # gshc_menu_select will set G_NBR global variable 
    gshc_menu_select "${MENU_PYOPENSSL}"  \
        "You already have the pyopenssl setup file. Select a number:" 3;
    PY_CHOICE="${G_NBR}"

    if ("${PY_CHOICE}" = "1"); then
        PYO_DOWNLOAD = "FALSE"
        PYO_INSTALL = "FALSE"
    elif ("${PY_CHOICE}" = "2"); then
        PYO_DOWNLOAD = "FALSE"
    fi
fi
    

if [ "${PYO_DOWNLOAD}" = "TRUE" ]; then
    cd /root/noarch
    # Download pyopenssl
    curl -L --url https://github.com/pyca/pyopenssl/archive/master.zip > pyopenssl.zip

    unzip pyopenssl.zip
fi

if [ "${PYO_INSTALL}" = "TRUE" ]; then
    if [    -d pyopenssl-master ]; then
        cd pyopenssl-master
    else
        echo "Error. The pyopenssl-master directory does not exist"
    fi
    if !( /usr/local/bin/python3 setup.py install --user); then
        echo "Error. The install for PyOpenSSL failed."
        gshc_continue;
    fi
fi

###############################################################################
clear
echo "Shard servers do not rely on the usual SSL certificates that are"
echo "signed by certificate authorities.  It is expected that shard serers"
echo "will use self-signed certificates."
echo
if (gshc_confirm "Do you want to generate a self-signed SSL certificate? " \
        "(y/n): " ); then
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
         

    # Do the next openssl commands ONLY FOR SELF-SIGNED CERTIFICATE.
    # create the self-signed certificate
    echo "When the X509 certificate request is being created,"
    echo "you need to enter the correct domain name or IP in the"
    echo "Common Name field (do not include 'http://')"
    openssl x509 -req -inform PEM -outform PEM -days 63 \
        -in ca.csr -signkey ca.key -out ca.crt

    # You can run this to get information from your crt file:
    openssl x509 -text -in ca.crt # get info
    if [ ! -d "${CERT_KEY_ROOT}" ]; then
        mkdir -p "${CERT_KEY_ROOT}"
    fi
    chown -R natmsg:natmsg "${CERT_KEY_ROOT}"
    chmod 700 "${CERT_KEY_ROOT}"

    # Make a copy of any old keys, and append a date-stamp to the file name:
    if ! (gshc_safe_move \
            "${CERT_KEY_ROOT}/ca.key" \
            "${CERT_KEY_ROOT}/${DSTAMP}.ca.key" ); then
        echo "Error. Failed to archive a key file"
        exit 239
    fi

    if !(gshc_safe_move \
            "${CERT_KEY_ROOT}/ca.csr" \
            "${CERT_KEY_ROOT}/${DSTAMP}.ca.csr"); then
        echo "Error. Failed to archive a key file"
        exit 239
    fi

    if !(gshc_safe_move  \
            "${CERT_KEY_ROOT}/ca.crt" \
            "${CERT_KEY_ROOT}/${DSTAMP}.ca.crt"); then
        echo "Error. Failed to archive a key file"
        exit 239
    fi

    cp -i /root/noarch/keytemp/ca.crt "${CERT_KEY_ROOT}"
    cp -i /root/noarch/keytemp/ca.key "${CERT_KEY_ROOT}"

    chown natmsg:natmsg "${CERT_KEY_ROOT}/*"
fi

# Test real ssl certificates here (no self-signed certs):
# https://www.ssllabs.com/ssltest/

############################################################
## # The Requests lib for python comes from
## # http://docs.python-requests.org/en/latest/user/install/#get-the-code
## # and the downloaded directory looks something like this:
## # kennethreitz-requests-359659c

if (gshc_confirm "Do you want to install the python requests " \
        "library from source? "); then
    cd /root/noarch
    if [ ! -f requests-master.tar.gz ]; then
        curl -L \
            --url https://github.com/kennethreitz/requests/tarball/master > requests-master.tar.gz
    fi
   
    if [ ! -f requests-master.tar ]; then
        gunzip requests-master.tar.gz
    fi
   
    tar -xf requests-master.tar
   
    ##cd kennethreitz-requests-122c92e
    dir_name=$(ls -lotrd kennethreitz-requests* |tail -n 1|cut -d ' ' -f 9)
    cd "${dir_name}"
   
    # Be sure to execute the correct version of Python3,
    # which might not be in the usual directory.
    /usr/local/bin/python3 setup.py install
fi

############################################################
# install libgcrypt and dependencies... used by nm_verify
# BE CAREFUL TO NOT INSTALL THE DEFAULT PINENTRY--IT WILL INSTALL GUI
# here is a list of current downloads from a mirror in Canada:
# http://gnupg.parentinginformed.com/download/index.html#libgpg-error
##
### In Dec 2014, CentOS7 still had libgcrypt 1.5.3 and for some reason
### it did not work with elliptic keys
## yum install libgcrypt-devel libksba-devel libassuan-devel

if (gshc_confirm "Do you want to compile gpg-error (required before " \
        "libgcrypt)? " ); then
    if [ ! -d /root/c/lib ]; then
        mkdir -p /root/c/lib
    fi

    cd /root/c/lib

    if [ -f ${LIBGPGERR_VER}.tar.bz2 ]; then
        if (gshc_confirm "The libgpg-error  source file already exists.  " \
                "Do you want  to DELETE that version? " ); then
            rm ${LIBGPGERR_VER}.tar.bz2
        fi
    fi

    if [ ! -f ${LIBGPGERR_VER} ]; then
        wget ftp ftp://ftp.gnupg.org/gcrypt/libgpg-error/${LIBGPGERR_VER}.tar.bz2
        wget ftp://ftp.gnupg.org/gcrypt/libgpg-error/${LIBGPGERR_VER}.tar.bz2.sig
    fi

    if [ -d ${LIBGPGERR_VER} ]; then
        echo "The libgpgerr directory already exists.  I will rename it."
        mv ${LIBGPGERR_VER} ${LIBGPGERR_VER}${DSTAMP}
    fi

    if [ -f ${LIBGPGERR_VER}.tar ]; then
        echo "The libgpgerr tar file already exists. I will rename it."
        mv ${LIBGPGERR_VER}.tar ${LIBGPGERR_VER}.tar.${DSTAMP}
    fi

    if ! bunzip2 "${LIBGPGERR_VER}.tar.bz2"; then
        echo "Error, failed to unzip the ${LIBGPGERR_VER}.tar.bz2"
    else
        tar -xf "${LIBGPGERR_VER}.tar"

        cd "${LIBGPGERR_VER}" 
        if ! ./configure --enable-static --disable-shared \
                --prefix=/usr/local; then
            echo "Error. failed to configure ${LIBGPGERR_VER}"
            exit 12
        else
            # the static lib is lib/libgpg-error/src/.libs/libgpg-error.a
            if ! make; then
                echo "Error. Failed to make libgpg-error, which is " \
                    "needed for libgcrypt"
                exit 144
            else
                if ! make install; then
                    echo "Error. Failed to install libgpg-error, which is " \
                        "needed for libgcrypt"
                    exit 145
                fi
            fi
        fi
    fi
fi #end of gpg-error install

########################################################################
if (gshc_confirm "Do you want to compile libgcrypt? " ); then
    if [ ! -d /root/c/lib ]; then
        mkdir -p /root/c/lib
    fi

    cd /root/c/lib
    if [    -f ${LIBGCRYPT_VER}.tar.bz2 ]; then
        if (gshc_confirm "The libgcrypt source file already exists.  " \
            "Do you want to DELETE that version? (y/n): " ); then
            rm ${LIBGCRYPT_VER}.tar.bz2
        fi
    fi

    if [ ! -f ${LIBGCRYPT_VER}.tar.bz2 ]; then
        wget ftp://ftp.gnupg.org/gcrypt/libgcrypt/${LIBGCRYPT_VER}.tar.bz2
        wget ftp://ftp.gnupg.org/gcrypt/libgcrypt/${LIBGCRYPT_VER}.tar.bz2.sig
    fi

    if [ -d ${LIBGCRYPT_VER} ]; then
        echo "The libgcrypt directory already exists.     I will rename it."
        mv ${LIBGCRYPT_VER} ${LIBGCRYPT_VER}${DSTAMP}
    fi

    if [ -f ${LIBGCRYPT_VER}.tar ]; then
        echo "The libgcrypt tar file already exists.     I will rename it."
        mv ${LIBGCRYPT_VER}.tar ${LIBGCRYPT_VER}.tar.${DSTAMP}
    fi

    if ! bunzip2 ${LIBGCRYPT_VER}.tar.bz2; then
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
    if ! make; then
        echo "Error.    Failed to make libgcrypt."
        exit 133
    fi
    if !(make install); then
        echo "Error.    Failed to run make install libgcrypt."
        exit 133
    fi
fi

if [ -f /root/c/lib/${LIBGCRYPT_VER}/src/.libs/libgcrypt.a ]; then
    # this might not be necessary now that I run the install above
    install -t /usr/local/lib  \
        /root/c/lib/${LIBGCRYPT_VER}/src/.libs/libgcrypt.a
    chown root:root /usr/local/bin/libgcrypt.*
    echo "I now have a static library for libgcrypt that can "
    echo "be compiled into my other programs"
else
    echo "Error. I did not find the static library for libgcrypt"
    echo "that can be compiled into my other programs"
    gshc_continue;
fi

###############################################################################
#     Configure the postgres user ID.
#
# Note that different systems will put the postgres home
# directory in different places, hence the PGUSER_HOME variable.
#
echo "Preparing the SQL for the shard server..."


if grep '^postgres[:]' /etc/passwd; then
    # The postgres user exists. Create some directories.
    if [ ! -d "${PGUSER_HOME}/shardsvr/sql" ]; then
        mkdir -p "${PGUSER_HOME}/shardsvr/sql"
    fi

    chown -R postgres:postgres "${PGUSER_HOME}"
fi

echo "SQL source DIR is ${SOURCE_DIR}"

if [ ! -s "${PGUSER_HOME}/shardsvr/sql/0010setup.sql" ]; then
    # The sql file is not in the permanent place..
    if [ -s "${SOURCE_DIR}/sql/0010setup.sql" ]; then
        # Copy the sql from the untarred github directory
        echo "Copying SQL from ${SOURCE_DIR}"
        cp -r "${SOURCE_DIR}/sql" "${PGUSER_HOME}/shardsvr"
    else
        echo "Error. I can not find the source sql files. They should be in"
        echo "the sql subdirectory in the github file."
        exit 493
    fi
fi

chown -R postgres:postgres "${PGUSER_HOME}"
###############################################################################
###############################################################################
#     Configure the sysmon (monitors server stats)
#
# Note that different systems will put the postgres home
# directory in different places, hence the PGUSER_HOME variable.
#

if grep '^postgres[:]' /etc/passwd; then
    # The postgres user exists. Create some directories.
    if [ ! -d "${PGUSER_HOME}/sysmon/sql" ]; then
        mkdir -p "${PGUSER_HOME}/sysmon/sql"
    fi

    chown -R postgres:postgres "${PGUSER_HOME}"
fi

if [ ! -s "${PGUSER_HOME}/sysmon/0510sysmon.sql" ]; then
    # The sql file is not in the permanent place..
    if [ -s "${SOURCE_DIR}/sysmon/0510sysmon.sql" ]; then
        # Copy the sql from the untarred github directory
        echo "Copying sysmon SQL from ${SOURCE_DIR}"
        cp  "${SOURCE_DIR}/sysmon/*" "${PGUSER_HOME}/sysmon"
    else
        echo "Error. I can not find the source sql files for sysmon. They should be in"
        echo "the symon subdirectory in the github file."
        exit 498
    fi
fi

chown -R postgres:postgres "${PGUSER_HOME}"
###############################################################################
# Start the database (if it is not running), then
# Create the database and build the tables.

cd "${PGUSER_HOME}/shardsvr/sql"

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

db_existence=$(sudo -u postgres psql  -c '\q' ${DBNAME})
if [ $? = 0 ]; then
    echo "The shardsvrdb database exists."
else
    echo "I did not find the shardsvrdb.  I will create it now"
    cd "${PGUSER_HOME}/shardsvr/sql"
    sudo -u postgres ./0002create_db.sh
fi

cd "${PGUSER_HOME}/shardsvr/sql"
db_existence=$(sudo -u postgres psql -c '\q'  ${DBNAME})
if [ $? != 0 ]; then
    echo "Error. Failed to create the shardsvrdb database."
    exit 834
fi

# Run an SQL command to look at a table -- this is an indicator
# of whether the tables have been created:
chk_shard=$(sudo -u postgres psql \
    -c '\d shardsvr.big_shards' ${DBNAME} |grep big_shard_pkid|tail -n 1)

if [ -z "${chk_shard}" ]; then
    # I do not see a shard table, so I should install the shard tables:
        if [ -f "${PGUSER_HOME}/shardsvr/sql/0002create_db.sql" ]; then
            cd "${PGUSER_HOME}/shardsvr/sql"
            sudo -u postgres psql  -c "\i 0002create_tables.sql" "${DBNAME}"
        fi
    
    # 
    clear
    # Get a password to initialize the database, save it in 0010once.sql
    # Note that the db password will be in other files online, so this
    # adds no additional security threat.  One improvement might be to
    # put all files and programs in an encrypted drive.
    #
    ##read -s -p "Enter a new password for the database: " NEW_DB_PW
    read -p "Enter a new password for the database: " NEW_DB_PW
    cat "${PGUSER_HOME}/shardsvr/sql/0010setup.sql"|sed \
        -e "s/ENTER_THE_DATABASE_PASSWORD/${NEW_DB_PW}/" > \
        "${PGUSER_HOME}/shardsvr/sql/0010once.sql"
    
    cat "${PGUSER_HOME}/shardsvr/sql/0010once.sql"|grep pass
    echo "Check the line above. If you alread have the database password " \
        "in 0010setup.sql"
    echo -n "Do you want to initialize the database for "
    if (gshc_confirm "the shard server? (y/n): "); then 
        cd "${PGUSER_HOME}/shardsvr/sql"
        sudo -u postgres psql -c '\i 0010setup.sql' "${DBNAME}"
        sudo -u postgres psql -c '\i 0015shard_server.sql' "${DBNAME}"
        sudo -u postgres psql -c '\i 0016shard_server_big.sql' "${DBNAME}"
        sudo -u postgres psql -c '\i functions/scan_shard_delete.sql' "${DBNAME}"
        sudo -u postgres psql -c '\i functions/shard_burn.sql' "${DBNAME}"
        sudo -u postgres psql -c '\i functions/shard_delete.sql' "${DBNAME}"
        sudo -u postgres psql -c '\i functions/shard_expire.sql' "${DBNAME}"
        sudo -u postgres psql -c '\i functions/sysmon010.sql' "${DBNAME}"
        sudo -u postgres psql -c '\i functions/shard_burn_big.sql' "${DBNAME}"
        sudo -u postgres psql -c '\i functions/shard_delete_db_entries.sql' "${DBNAME}"
        sudo -u postgres psql -c '\i functions/shard_expire_big.sql' "${DBNAME}"
        sudo -u postgres psql -c '\i functions/shard_id_exists.sql' "${DBNAME}"
    fi
else
    echo "I am not installing the shard server tables because I already " \
        "found a shard table."
fi

###############################################################################
###############################################################################
if (gshc_confirm "Do you want to download and install the natmsgv program " \
    " to get the key signing routine (required for server " \
    "operation)? (y/n): "); then
    cd /root/noarch
    wget \
        https://github.com/naturalmessage/natmsgv/archive/master.tar.gz \
        -O natmsgv.tar.gz
    gunzip natmsgv.tar.gz
    tar -xf natmsgv.tar
    cd natmsgv-master
    make

    if [ $? != 0 ]; then
        echo "Failed to make natmsgv (server verification C program"
    fi
    cp nm_verify /var/natmsg
    cp nm_sign /var/natmsg
    chown natmsg:natmsg /var/natmsg/nm_*
fi
###############################################################################
###############################################################################
###############################################################################
###############################################################################
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
" terminal color for comment.  On some systems,
" it is set to darkblue which is too dark
:highlight Comment ctermfg=darkgreen guifg=darkgreen
EOF
fi

if [ ! -f /home/natmsg/.vimrc ]; then
    cp /root/.vimrc /home/natmsg/.vimrc
    chown natmsg:natmsg /home/natmsg/.vimrc
fi


if [ ! -f /root/.screenrc ]; then
cat <<EOF > /root/.screenrc
shelltitle "zz%t%"
hardstatus on
hardstatus alwayslastline
hardstatus string "%{.bW}%-w%{.rW}%n %t%{-}%+w %=%{..G} %H %{..Y} %m/%d %C%a "
#hardstatus string "%t%"
EOF
fi

if [ ! -f /home/natmsg/.screenrc ]; then
    cat /root/.screenrc|sed -e 's/[.]bW/.gW/' > /home/natmsg/.screenrc
    chown natmsg:natmsg /home/natmsg/.screenrc
fi
###############################################################################
rslt=$(crontab -l|grep monitor.py)
    if [    -z "${rslt}" ]; then
    echo "============================================================"
    echo "Manual crontab setup:"
    echo "Create a cron job to run /var/natmsg/monitor.py every 5 min"
    echo "under the root user ID.  Use this command:"
    echo "   sudo crontab -e"
    echo "to edit a crontab, then past the example text, and double check"
    echo "the python3 program name and the python script file name."
    echo "*/5 * * * * /usr/local/bin/python3 /var/natmsg/monitor.py"
    echo "copy the line above with the mouse and prepare to "
    echo "paste it into crontab..."
    gshc_continue
    crontab -e
fi
###############################################################################
