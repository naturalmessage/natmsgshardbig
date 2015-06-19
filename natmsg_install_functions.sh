#!/bin/bash
#
###############################################################################
# Copyright 2015 Natural Message, LLC.
# Author: Robert Hoot (naturalmessage@fastmail.fm)
#
# This file is part of the Natural Message Shard Server.
#
# The Natural Message Shard Server is free software: you can redistribute
# it and/or modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# Natural Message Shard Server is distributed in the hope that it will
# be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Natural Message Shard Server.  If not,
# see <http://www.gnu.org/licenses/>.
###############################################################################
# This is a collection of shell script functions (for bash) that are
# used to install the shard server.  This is currently for Debian 7,
# but I will eventually make this work for multiple OSs.
# 
# This is explicitly for bash, not tcsh.
#
# Do not bother running this on an OS that is not explictly supported.
###############################################################################
install_python_tar_gz(){
    # This will take a URL (typically a github url) in tar.gz format
    # and then download the file, gunzip it, untar it, and run
    # the python setup.py install command to install the package.
    # The downloaded files go in /root/noarch
    #
    # This assumes tha the first line of the tar file is an entry
    # for the project subdirectory.
    
    url="$1"

    if [ -z "$1" ]; then
        echo "Error.  There was no URL sent to install_python_tar_gz."
        return 893
    fi

    if [ ! -d /root/noarch ] ; then
        mkdir -p /root/noarch
    fi
    cd /root/noarch

    # Verify that the argument is a URL.
    scheme=$(echo "$1" |cut -d ':' -f 1| tr '[[:upper:]]' '[[:lower:]]')
    good="FALSE"
    if [ "${scheme}" = "http" ]; then
        good="TRUE"
    elif[ "${scheme}" = "https" ]; then
        good="TRUE"
    fi

    if [ "${good}" = "FALSE" ]; then
        echo "Error.  The argument sent to install_python_tar_gz was not a url."
        return 892
    fi

    # Prepare for download
    download_fname=$(basename "${url}")
    tar_fname=$(echo "${download_fname}"|cut -d '.' -f 1-2)

    if [ ! "${tar_fname}.gz" = "${download_fname}" ]; then
        echo "Error. The expected tar file name was did not match the"
        echo "calculated value."
        return 984
    fi
    curl -L --url "${url}" > "${download_fname}"

    # Unzip and untar.
    gunzip "${download_fname}"

    proj_dir=$(tar -xf "${tar_fname}"|head -n 1)
    tar -xf "${tar_fname}"

    if [ ! -d "${proj_dir}" ]; then
        echo "Error.  The project subdirectory was not found: ${proj_dir}."
        return 986
    fi

    # Run the python install using python3 from /usr/local/bin
    cd "${proj_dir}"
    if !(/usr/local/bin/python3 setup.py install); then
        echo "Error.  The python setup command failed."
        return 987
    fi

    return 0
}
###############################################################################
###############################################################################
###############################################################################
###############################################################################
###############################################################################

initial_installs(){
    # Miscellaneous programs needed for general purposes
    # or preparation for subsequent installs.
    # basics:
    if [ ! -d /root/noarch ]; then
        mkdir -p /root/noarch
    fi
    cd /root/noarch

    apt-get -y install vim lynx screen rsync
    apt-get -y install curl wget # needed for installs
    apt-get -y install fail2ban
    apt-get -y install zip  # needed to open pyopenssl package 
    # apps needed to install and compile the Natural Message server 
    # verification C programs.
    apt-get -y install gcc
    apt-get -y install make
    echo "bzip2 (bz2) with C headers is needed for the libgcrypt install."
    #apt-get -y install bzip2-devel
    apt-get source bzip2
    #
    #
    # Devel headers needed for pyOpenssl to tet TLS_1_2
    #apt-get -y install openssl
    apt-get -y install dpkg-dev
    apt-get source openssl
    #
    # apt-get -y install lib${ARCHBITS}ncurses5-dev

    apt-get -y install zlib1g-dev

    apt-get source lib${ARCHBITS}ncurses5-dev
    # apt-get -y install sqlite3
    apt-get source sqlite3

    #apt-get -y install readline
    apt-get source readline

    #apt-get -y install libpcap
    apt-get source libpcap

    # apt-get -y install xz-utils
    apt-get source xz-utils

    return 0
}
###############################################################################
###############################################################################
###############################################################################
# needs SOURCE_DIR
natmsg_dir_setup(){
    if [ -z "$1" ];then
        echo "Error. You are missing an argument for the source directory"
        echo "for natmsg_dir_setup."
        exit 345
    fi

    local source_directory="$1"

    if [ ! -d "${source_directory}" ]; then
        echo "Error. The source directory for natmsg_dir_setup does not exist."
        exit 346
    fi

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
        tst_file="${source_directory}/private/TestKeys/JUNKTESTOfflinePUBSignKey.key"
        if [ -f "${tst_file}" ]; then
            # Copy the sql from the untarred github directory
            echo "Copying SQL from ${source_directory}"
            cp -rn "${source_directory}/private/TestKeys" /var/natmsg/private
            chmod 700 /var/natmsg/private
            chown -R natmsg:natmsg /var/natmsg/private
        else
            echo "Error. I can not find the source test keys. They should be in"
            echo "the sql subdirectory in the github file (under ${source_directory})."
            echo "Test file was ${tst_file}"
            exit 493
        fi
    fi

    # Copy the main Python programs to /var/natmsg (with no-clobber option)
    # Note: do not put the source path in quotes or it will not work
    # due to the wildcard.
    cp -n ${source_directory}/psql*.sh /root
    cp -n ${source_directory}/*.py /var/natmsg
    cp -n ${source_directory}/conf/*.conf /var/natmsg/conf
    chown -R natmsg:natmsg /var/natmsg/conf
    chmod -R 700 /var/natmsg/conf
    chmod -R 700 /var/natmsg/private

    # ntpdate will disappear, but it works for now
    apt-get -y install ntpdate
    # sync the time
    ntpdate 2.fedora.pool.ntp.org

    chmod  700 /var/natmsg/
    chmod  700 /var/natmsg/*.py
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

    return 0
} # end natmsg_dir_setup


###############################################################################
###############################################################################
###############################################################################
# Python 3 from source seems to be needed for Debian because
# the builtin _ssl lib did not have TLS_1_2.
# needs PYTHON_VER
natmsg_install_python(){
    python_version="$1"
    if (gshc_confirm "Do you want to install Python3 from source? (y/n): " ); then
        if [ ! -d /root/noarch ]; then
            mkdir -p /root/noarch
        fi
        cd /root/noarch
        if [ -f Python-${python_version}.tgz ]; then
        prmpt="The Python 3 source file already exists. Do you want to DOWNLOAD THAT FILE AGAIN? (y/n): "
            if (gshc_confirm "${prmpt}" ); then
                rm Python-${python_version}.tgz
            fi
        fi

        if [ ! -f Python-${python_version}.tgz ]; then
            # The Python file is not already here, so download it...
            wget https://www.python.org/ftp/python/${python_version}/Python-${python_version}.tgz
            tar xf Python-${python_version}.tgz
        fi

        if [ -d Python-${python_version} ]; then
            cd Python-${python_version}
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

    #----------------------------------------------------------------------
    echo "Installing setuptools (ez_setup) from source."
    if [ ! -d /root/noarch ]; then
      mkdir -p /root/noarch
    fi
    cd /root/noarch
    wget https://bootstrap.pypa.io/ez_setup.py
    python3 ez_setup.py

    return 0
} # end natmsg_install_python

###############################################################################
###############################################################################
###############################################################################
### ### # Test if a natural message shard server program is already in the target
### ### # directory.
### ### chk_natmsg=$(ls /var/natmsg/naturalmsg_shard*| grep naturalmsg|head -n 1)
### ### if [ -z "${chk_natmsg}" ]; then
### ###     PRMPT="You already have at least one version of the natural message " \
### ###         "shard server program.  Do you want to download and install a " \
### ###         "fresh version of the the Natural Message shard server Python " \
### ###         "code? (y/n): " 
### ### else
### ###     PRMPT="Do you want to download and install a fresh version " \
### ###         "of the the Natural Message shard server Python code? (y/n): " 
### ### fi
### ### 
### ###     # there are no versions of the shard server, so install it
### ### if (gshc_confirm "${PRMPT}" ); then
### ###     echo "Downloading the shard server"
### ### 
### ###     if [ ! -d /root/noarch ]; then
### ###         mkdir -p /root/noarch
### ###     fi
### ###     cd /root/noarch
### ### 
### ###     curl -L --url https://github.com/naturalmessage/natmsgshardbig/archive/master.tar.gz > natmsgshardbig.tar.gz
### ###     gunzip natmsgshardbig.tar.gz
### ###     tar -xf natmsgshardbig.tar
### ###     cd natmsgshardbig-master
### ###     chown natmsg:natmsg *
### ###     cp * /var/natmsg
### ### fi
###############################################################################
###############################################################################
###############################################################################
###############################################################################
# Install Postgres after Python 3 
# (and its dependencies, especially openssl source) has been
# installed (so that the postgre-python stuff can be 
# installed now

# needs ${PGSQL_BIN_DIR} = the directory with postgre sql binaries
# needs PGSQL_DATA
# needs PGUSER_HOME
# needs PSYCOPG_VER
natmsg_install_postgre(){
    local pgsql_bin_dir="$1"
    local pgsql_sql_data_dir="$2"
    local pguser_home_dir="$3"
    local psycopg_version="$4"

    local install_p="FALSE"

    if [ -f "${pgsql_bin_dir}/pg_ctl" ]; then
        echo
        echo
        echo "Postgres appears to be installed already."
        if (gshc_confirm "Do you want to re-install PostgreSQL? (y/n): "); then
            install_p="TRUE"
        fi
    else
        if (gshc_confirm "Do you want to install PostgreSQL? (y/n): "); then
            install_p="TRUE"
        fi
    fi

    if [ "${install_p}" = "TRUE" ]; then
        # Install PostgreSQL
        #
        apt-get -y install postgresql-server-dev-all
        apt-get -y install postgresql postgresql-client
        apt-get source postgresql-server-dev-all
        apt-get -y install pgp # for verification of downloaded files.
        
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
        echo "the Debian apt-get -y install is:"
        echo "   ${pgsql_data_dir}"
        echo "(Note that on my other setup the 'main' dir is called 'data'.)"
        echo ""
        gshc_continue;

        echo ""
        echo ""
        echo ""
        echo "If installed from apt-get, the command for db setup is:"
        echo "   whereis pg_ctl"
        echo "   sudo -u postgres ${pgsql_bin_dir}/pg_ctl -D ${pgsql_data_dir} initdb"
        echo ""
        echo ""
        if [ -d "${pgsql_data_dir}"  ]; then
            # maybe also check for /var/lib/postgresql/9.1/main/postgresql.conf
            if [ ! -d "${pgsql_data_dir}/base" ]; then
                sudo -u postgres "${pgsql_bin_dir}/pg_ctl" -D "${pgsql_data_dir}" initdb
            else
                echo "It looks like the database was already initalized in " \
                    "/var/lib/pgsql/data"
            fi
        else
            echo "ERROR. there is no pg data directory in the expected place: " \
                "${pgsql_data_dir}" 
            read -p "..." junk
        fi
        
        #-------------------------------------
        # one-time setup for postgres because it often
        # complains about permissions
        if [ ! -d  "${pguser_home_dir}/shardsvr" ]; then
            mkdir -p "${pguser_home_dir}/dirsvr"
            mkdir -p "${pguser_home_dir}/functions"
            mkdir -p "${pguser_home_dir}/shardsvr"
            mkdir -p "${pguser_home_dir}/sysmon"
        fi
        chown -R postgres:postgres "${pguser_home_dir}"
        chmod -R 700 "${pguser_home_dir}"
        
        
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
            # # "${pgsql_bin_dir}/postgres" \
            # #     -D "${pgsql_data_dir}" -c config_file="${PGSQL_CONF}"
            cd "${pguser_home_dir}"
            sudo -u postgres "${pgsql_bin_dir}/postgres" \
                -D "${pgsql_data_dir}"  > logfile 2>&1 &
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
        wget https://pypi.python.org/packages/source/p/psycopg2/psycopg2-${psycopg_version}.tar.gz
        wget https://pypi.python.org/packages/source/p/psycopg2/psycopg2-${psycopg_version}.tar.gz.asc # sig
        
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
        apt-get -y install libpqxx3-dev
        gunzip psycopg2-${psycopg_version}.tar.gz
        tar -xf psycopg2-${psycopg_version}.tar
        cd psycopg2-${psycopg_version}
        # You must run the correct python3 executable.  There might
        # be an old verion in /usr/bin.
        /usr/local/bin/python3 setup.py    install
        
    fi

    return 0
} # end of postgres install

###############################################################################
###############################################################################
###############################################################################
###############################################################################
# See if cherrypy is installed, and install it if need be
natmsg_install_cherrypy(){
    local install_cp="FALSE"

    python3 -c 'import cherrypy'
    if [ $? = 0 ]; then
        echo "Cherrypy (web server/Python module) was already installed"
        if (gshc_confirm "Do you want to reinstall CherryPy? (y/n): "); then
            install_cp="TRUE"
        fi
    else
        install_cp="TRUE"
    fi

    if [ "${install_cp}" = "TRUE" ]; then
        clear
        echo "Cherrypy web server/Python module is not installed.  Installing now."
        # In Debian 8, this will change to python3-cherrypy3
        #
        #    CherryPi
        # Debian 8 will hav a package for python3-cherrypy3 that should
        # simplify the install.  This install will be from source.
        #
        # I need the mercurial VCS to get the source
        apt-get -y install mercurial 
        ############################################################
        ############################################################
        
        mkdir -p /root/noarch/CherryPySource
        cd /root/noarch/CherryPySource
        hg clone https://bitbucket.org/cherrypy/cherrypy
        cd cherrypy
        # Remember to use the correct version of python in the correct dir.
        /usr/local/bin/python3 setup.py install
    else
        echo "Skipping CherryPy install."
    fi

    return 0
}
###############################################################################
###############################################################################
###############################################################################
###############################################################################
###############################################################################
# I will ship RNCryptor directly, so I do not need this RNCryptor stuff:
## RNCryptor - encryption package used by the client app.
# ## also used for PBKDF2 for password-strengthening
# #cd /var/natmsg
# #curl -L --url https://github.com/RNCryptor/RNCryptor-python/raw/master/RNCryptor.py > /var/natmsg/RNCryptor.py
# #chmod 644 RNCryptor.py

###############################################################################
###############################################################################
###############################################################################
###############################################################################
###############################################################################
###############################################################################
###############################################################################
natmsg_install_crypto(){
    # This will install both the python cryptography package and the
    # python PyCrypto package as dependencies for pyopenssl.
    #
    # Because Python will be compiled from source on some systems and run
    # from al alternative directory, the standard "yum install"
    # or "apt-get install" commands do not put the packages in the right
    # directory, so I install lots of things from source (originally
    # needed for Debian 7).

    local six_version="$1"
    local pycparser_version="$2"
    local cffi_version="$3"
    local pyasn_version="$4"
    local idna_version="$5"
    local cryptography_version="$6"
    local crypto_version="$7"

    if [ ! -d /root/noarch ]; then
        mkdir /root/noarch
    fi

    if [ ! -d /root/noarch ]; then
        return 9911
    fi
    
    cd /root/noarch

    if !(install_python_tar_gz https://pypi.python.org/packages/source/s/six/six-${six_version}.tar.gz); then
        echo "Error.  Failed to download and install six (needed by pyopenssl)."
        gshc_pause
    fi

    if !(install_python_tar_gz https://pypi.python.org/packages/source/p/pycparser/pycparser-${pycparser_version}.tar.gz); then
        echo "Error.  Failed to download and install pycparser."
        gshc_pause
    fi

    if !(install_python_tar_gz https://pypi.python.org/packages/source/c/cffi/cffi-${cffi_version}.tar.gz); then
        echo "Error.  Failed to download and install cffi."
        gshc_pause
    fi

    if !(install_python_tar_gz https://pypi.python.org/packages/source/p/pyasn1/pyasn1-${pyasn_version}.tar.gz); then
        echo "Error.  Failed to download and install pyasn1."
        gshc_pause
    fi

    if !(install_python_tar_gz https://pypi.python.org/packages/source/i/idna/idna-${idna_version}.tar.gz); then
        echo "Error.  Failed to download and install idna."
        gshc_pause
    fi

    if !(install_python_tar_gz https://pypi.python.org/packages/source/c/cryptography/cryptography-${crypotgraphy_version}.tar.gz); then
        echo "Error.  Failed to download and install cryptography."
        gshc_pause
    fi



    python3 -c 'import Crypto'

    if [ $? = 0 ]; then
        echo "The python Crypto library is already installed."
    else
        echo "The python Crypto library is NOT installed... Installing it now."

        install_python_tar_gz https://ftp.dlitz.net/pub/dlitz/crypto/pycrypto/pycrypto-2.6.1.tar.gz
        # RNCryptor requires the Crypto python library, which
        # is described here: https://www.dlitz.net/software/pycrypto/doc/
        
        curl -L --url https://ftp.dlitz.net/pub/dlitz/crypto/pycrypto/pycrypto-2.6.1.tar.gz > /root/noarch/pycrypto.tar.gz
        
        cd /root/noarch
        gunzip /root/noarch/pycrypto.tar.gz
        tar -xf /root/noarch/pycrypto.tar
        crypto_dir=$(ls -d pycrypto-* |sort -r|head -n 1)
        cd "${crypto_dir}"
        # Be sure to run the correct version of python from
        # the correct directory
        /usr/local/bin/python3 setup.py install
    fi

    return 0
}

###############################################################################
###############################################################################
###############################################################################


install_open_ssl(){
    #                       OpenSSL for CherryPy
    #
    # The built-in version of the python ssl lib in Debian7 did not have tls 1.2
    # Installing PyOpenSSL is not enough.  For Debian 7, you first need to
    # install the openssl source so that the system has the right program,
    # then after that is installed, comiling pyopenssl here will get the
    # correct binaries.
    #
    # install libffi with headers:
    apt-get -y install libffi-dev

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
    if [ -f /root/noarch/pyopenssl-master/setup.py ]; then
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
        if [    -d /root/noarch/pyopenssl-master ]; then
            cd pyopenssl-master
        else
            echo "Error. The pyopenssl-master directory does not exist"
        fi
        if !( /usr/local/bin/python3 setup.py install --user); then
            echo "Error. The install for PyOpenSSL failed."
            gshc_continue;
        fi
    fi

    return 0
}
###############################################################################

install_self_signed_cert(){
    local cert_key_root_dir="$1"
    local dstamp="$2"

    if [ ! -d "${cert_key_root_dir}" ]; then
        echo "Error. The certificate key root dir is invalid in install_self_signed_cert:"
        echo "${cert_key_root_dir}"
        return 845
    fi

    if [ -z "${dstamp}" ]; then
        echo "Error. File suffix (date stamp) is missing in install_self_signed_cert."
        return 845
    fi

    clear
    echo "Shard servers do not rely on the usual SSL certificates that are"
    echo "signed by certificate authorities.  It is expected that shard serers"
    echo "will use self-signed certificates."
    echo
    prmpt="Do you want to generate a self-signed SSL certificate? (y/n): " 
    if (gshc_confirm "${prmpt}" ); then
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
        if [ ! -d "${cert_key_root_dir}" ]; then
            mkdir -p "${cert_key_root_dir}"
        fi
        chown -R natmsg:natmsg "${cert_key_root_dir}"
        chmod 700 "${cert_key_root_dir}"

        # Make a copy of any old keys, and append a date-stamp to the file name:
        if ! (gshc_safe_move \
                "${cert_key_root_dir}/ca.key" \
                "${cert_key_root_dir}/${dstamp}.ca.key" ); then
            echo "Error. Failed to archive a key file"
            exit 239
        fi

        if !(gshc_safe_move \
                "${cert_key_root_dir}/ca.csr" \
                "${cert_key_root_dir}/${dstamp}.ca.csr"); then
            echo "Error. Failed to archive a key file"
            exit 239
        fi

        if !(gshc_safe_move  \
                "${cert_key_root_dir}/ca.crt" \
                "${cert_key_root_dir}/${dstamp}.ca.crt"); then
            echo "Error. Failed to archive a key file"
            exit 239
        fi

        cp -i /root/noarch/keytemp/ca.crt "${cert_key_root_dir}"
        cp -i /root/noarch/keytemp/ca.key "${cert_key_root_dir}"

        chown -R natmsg:natmsg "${cert_key_root_dir}"
    fi

    return 0
}

# Test real ssl certificates here (no self-signed certs):
# https://www.ssllabs.com/ssltest/

############################################################

install_libgcrypt(){
    local libgpgerr_version="$1"
    local libgcrypt_version="$2"
    local dstamp="$3"

    if [ -z "${dstamp}" ]; then
        echo "Error.  The file suffix (date stamp) is missing in install_libgcrypt."
        return 4958
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

    prmpt="Do you want to compile gpg-error (required before libgcrypt)? (y/n): "
    if (gshc_confirm "${prmpt}" ); then
        if [ ! -d /root/c/lib ]; then
            mkdir -p /root/c/lib
        fi

        cd /root/c/lib

        if [ -f ${libgpgerr_version}.tar.bz2 ]; then
        prmpt="The libgpg-error  source file already exists.  Do you want  to DELETE that version? "
            if (gshc_confirm "${prmpt}"  ); then
                rm ${libgpgerr_version}.tar.bz2
            fi
        fi

        if [ ! -f ${libgpgerr_version} ]; then
            wget ftp ftp://ftp.gnupg.org/gcrypt/libgpg-error/${libgpgerr_version}.tar.bz2
            wget ftp://ftp.gnupg.org/gcrypt/libgpg-error/${libgpgerr_version}.tar.bz2.sig
        fi

        if [ -d ${libgpgerr_version} ]; then
            echo "The libgpgerr directory already exists.  I will rename it."
            mv ${libgpgerr_version} ${libgpgerr_version}${dstamp}
        fi

        if [ -f ${libgpgerr_version}.tar ]; then
            echo "The libgpgerr tar file already exists. I will rename it."
            mv ${libgpgerr_version}.tar ${libgpgerr_version}.tar.${dstamp}
        fi

        if ! bunzip2 "${libgpgerr_version}.tar.bz2"; then
            echo "Error, failed to unzip the ${libgpgerr_version}.tar.bz2"
        else
            tar -xf "${libgpgerr_version}.tar"

            cd "${libgpgerr_version}" 
            if ! ./configure --enable-static --disable-shared \
                    --prefix=/usr/local; then
                echo "Error. failed to configure ${libgpgerr_version}"
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
        if [    -f ${libgcrypt_version}.tar.bz2 ]; then
        prmpt="The libgcrypt source file already exists. Do you want to DELETE that version? (y/n): "
            if (gshc_confirm "${prmpt}"  ); then
                rm ${libgcrypt_version}.tar.bz2
            fi
        fi

        if [ ! -f ${libgcrypt_version}.tar.bz2 ]; then
            wget ftp://ftp.gnupg.org/gcrypt/libgcrypt/${libgcrypt_version}.tar.bz2
            wget ftp://ftp.gnupg.org/gcrypt/libgcrypt/${libgcrypt_version}.tar.bz2.sig
        fi

        if [ -d ${libgcrypt_version} ]; then
            echo "The libgcrypt directory already exists.     I will rename it."
            mv ${libgcrypt_version} ${libgcrypt_version}${dstamp}
        fi

        if [ -f ${libgcrypt_version}.tar ]; then
            echo "The libgcrypt tar file already exists.     I will rename it."
            mv ${libgcrypt_version}.tar ${libgcrypt_version}.tar.${dstamp}
        fi

        if ! bunzip2 ${libgcrypt_version}.tar.bz2; then
            echo "Error.    Failed to unzip libgcrypt."
            exit 133
        fi

        tar -xf ${libgcrypt_version}.tar
        cd ${libgcrypt_version}
        ## This needs to read the static version of libgpg-error to
        ## avoid confusion with the older version that might be in CentOS 7.
        ## The static library for libgpg-error is in 
        ## /root/c/lib/${libgpgerr_version}/src/.libs/libgpg-error.a

        # try to point to static lib
        export GPG_ERROR_LIBS=/root/c/lib/${libgpgerr_version}/src/.libs/
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

    if [ -f /root/c/lib/${libgcrypt_version}/src/.libs/libgcrypt.a ]; then
        # this might not be necessary now that I run the install above
        install -t /usr/local/lib  \
            /root/c/lib/${libgcrypt_version}/src/.libs/libgcrypt.a
        chown root:root /usr/local/bin/libgcrypt.*
        echo "I now have a static library for libgcrypt that can "
        echo "be compiled into my other programs"
    else
        echo "Error. I did not find the static library for libgcrypt"
        echo "that can be compiled into my other programs"
        gshc_continue;
    fi

    return 0
}


###############################################################################
configure_postgres_sql(){
    #     Configure the postgres directory to accept the SQL.
    #
    # Note that different systems will put the postgres home
    # directory in different places, hence the PGUSER_HOME variable.
    #
    local pguser_home_dir="$1"
    local source_dir="$2"

    if [ ! -d "${pguser_home_dir}" ]; then
        echo "Error. The source dir under which the original SQL is kept"
        echo "is not valid."
        return 4945
    fi

    if [ ! -d "${source_dir}" ]; then
        echo "Error. The source dir under which the original SQL is kept"
        echo "is not valid."
        return 4945
    fi

    echo "Preparing the SQL for the shard server..."

    if grep '^postgres[:]' /etc/passwd; then
        # The postgres user exists. Create some directories.
        if [ ! -d "${pguser_home_dir}/shardsvr/sql" ]; then
            mkdir -p "${pguser_home_dir}/shardsvr/sql"
        fi

        chown -R postgres:postgres "${pguser_home_dir}"
    fi

    echo "SQL source DIR is ${source_dir}"

    if [ ! -s "${pguser_home_dir}/shardsvr/sql/0010setup.sql" ]; then
        # The sql file is not in the permanent place..
        if [ -s "${source_dir}/sql/0010setup.sql" ]; then
            # Copy the sql from the untarred github directory
            echo "Copying SQL from ${source_dir}"
            cp -r "${source_dir}/sql" "${pguser_home_dir}/shardsvr"
        else
            echo "Error. I can not find the source sql files. They should be in"
            echo "the sql subdirectory in the github file."
            exit 493
        fi
    fi

    chown -R postgres:postgres "${pguser_home_dir}"

    return 0
}
###############################################################################
###############################################################################
#     Configure the sysmon (monitors server stats)
#
# Note that different systems will put the postgres home
# directory in different places, hence the PGUSER_HOME variable.
#

configure_sysmon(){
    local pguser_home_dir="$1"
    local source_dir="$2"

    if [ ! -d "${pguser_home_dir}" ]; then
        echo "Error. The source dir under which the original SQL is kept"
        echo "is not valid."
        return 6945
    fi

    if [ ! -d "${source_dir}" ]; then
        echo "Error. The source dir under which the original SQL is kept"
        echo "is not valid."
        return 6945
    fi

    if grep '^postgres[:]' /etc/passwd; then
        # The postgres user exists. Create some directories.
        if [ ! -d "${pguser_home_dir}/sysmon/sql" ]; then
            mkdir -p "${pguser_home_dir}/sysmon/sql"
        fi

        chown -R postgres:postgres "${pguser_home_dir}"
    fi

    if [ ! -s "${pguser_home_dir}/sysmon/0510sysmon.sql" ]; then
        # The sql file is not in the permanent place..
        if [ -s "${SOURCE_DIR}/sysmon/0510sysmon.sql" ]; then
            # Copy the sql from the untarred github directory
            echo "Copying sysmon SQL from ${SOURCE_DIR}"
            cp  "${SOURCE_DIR}/sysmon/*" "${pguser_home_dir}/sysmon"
        else
            echo "Error. I can not find the source sql files for sysmon. They should be in"
            echo "the symon subdirectory in the github file."
            exit 498
        fi
    fi

    chown -R postgres:postgres "${pguser_home_dir}"

    return 0
}
###############################################################################
initialize_natmsg_database(){
    # Start the database (if it is not running), then
    # Create the database and build the tables.

    local pguser_home_dir="$1"
    local pgsql_bin_dir="$2"
    local pgsql_data="$3"
    local dbname="$4"

    if [ ! -d "${pguser_home_dir}" ]; then
        echo "Error. The source dir under which the original SQL is kept"
        echo "is not valid."
        return 6945
    fi

    
    cd "${pguser_home_dir}/shardsvr/sql"

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
        ## "${pgsql_bin_dir}/postgres" -D "${pgsql_data}" -c config_file="${PGSQL_CONF}"
        cd "${pguser_home_dir}"
        sudo -u postgres "${pgsql_bin_dir}/postgres" -D "${pgsql_data}" &
        if [ ! $? = 0 ]; then
            echo "Error.  Could not start the postgreSQL database."
            exit 87
        fi
    fi

    db_existence=$(sudo -u postgres psql  -c '\q' ${dbname})
    if [ $? = 0 ]; then
        echo "The shardsvrdb database exists."
    else
        echo "I did not find the shardsvrdb.  I will create it now"
        cd "${pguser_home_dir}/shardsvr/sql"
        sudo -u postgres ./0002create_db.sh
    fi

    cd "${pguser_home_dir}/shardsvr/sql"
    db_existence=$(sudo -u postgres psql -c '\q'  ${dbname})
    if [ $? != 0 ]; then
        echo "Error. Failed to create the shardsvrdb database."
        exit 834
    fi

    # Run an SQL command to look at a table -- this is an indicator
    # of whether the tables have been created:
    chk_shard=$(sudo -u postgres psql \
        -c '\d shardsvr.big_shards' ${dbname} |grep big_shard_pkid|tail -n 1)

    if [ -z "${chk_shard}" ]; then
        # I do not see a shard table, so I should install the shard tables:
            if [ -f "${pguser_home_dir}/shardsvr/sql/0002create_db.sql" ]; then
                cd "${pguser_home_dir}/shardsvr/sql"
                sudo -u postgres psql  -c "\i 0002create_tables.sql" "${dbname}"
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
        cat "${pguser_home_dir}/shardsvr/sql/0010setup.sql"|sed \
            -e "s/ENTER_THE_DATABASE_PASSWORD/${NEW_DB_PW}/" > \
            "${pguser_home_dir}/shardsvr/sql/0010once.sql"
        
        cat "${pguser_home_dir}/shardsvr/sql/0010once.sql"|grep pass
        echo "Check the line above. If you alread have the database password " \
            "in 0010setup.sql"
        echo -n "Do you want to initialize the database for "
        if (gshc_confirm "the shard server? (y/n): "); then 
            cd "${pguser_home_dir}/shardsvr/sql"
            sudo -u postgres psql -c '\i 0010setup.sql' "${dbname}"
            sudo -u postgres psql -c '\i 0015shard_server.sql' "${dbname}"
            sudo -u postgres psql -c '\i 0016shard_server_big.sql' "${dbname}"
            sudo -u postgres psql -c '\i functions/scan_shard_delete.sql' "${dbname}"
            sudo -u postgres psql -c '\i functions/shard_burn.sql' "${dbname}"
            sudo -u postgres psql -c '\i functions/shard_delete.sql' "${dbname}"
            sudo -u postgres psql -c '\i functions/shard_expire.sql' "${dbname}"
            sudo -u postgres psql -c '\i functions/sysmon010.sql' "${dbname}"
            sudo -u postgres psql -c '\i functions/shard_burn_big.sql' "${dbname}"
            sudo -u postgres psql -c '\i functions/shard_delete_db_entries.sql' "${dbname}"
            sudo -u postgres psql -c '\i functions/shard_expire_big.sql' "${dbname}"
            sudo -u postgres psql -c '\i functions/shard_id_exists.sql' "${dbname}"
        fi
    else
        echo "I am not installing the shard server tables because I already " \
            "found a shard table."
    fi

    return 0
}
###############################################################################
###############################################################################
install_natmsg_v(){
    prmpt="Do you want to download and install the natmsgv program to get the key signing routine (required for server operation)? (y/n): "
    if (gshc_confirm "${prmpt}"); then
        if [ ! -d /root/noarch ] ; then
            mkdir -p /root/noarch
        fi
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
        # Note: do not put quotes around the thing with the wildcard.
        chown natmsg:natmsg /var/natmsg/nm_*
    fi

    return 0
}
###############################################################################
###############################################################################
###############################################################################
###############################################################################
natmsg_final_config(){
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
set shiftwidth=4

" tabstop is the width of the tab character.
set tabstop=4
set expandtab
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
    ###############################################################################
    rslt=$(sudo -u natmsg crontab -l|grep housekeeping)
        if [    -z "${rslt}" ]; then
        echo "============================================================"
        echo "Manual crontab setup:"
        echo "Create a cron job to run /var/natmsg/housekeeping_shardsvr.py  once per day."
        echo "under the root user ID.  Use this command:"
        echo "   sudo -u natmsg crontab -e"
        echo "to edit a crontab, then past the example text, and double check"
        echo "the python3 program name and the python script file name."
        echo "* 2 * * * /usr/local/bin/python3 /var/natmsg/housekeeping_shardsvr.py"
        echo "copy the line above with the mouse and prepare to "
        echo "paste it into crontab..."
        gshc_continue
        crontab -e
    fi

    return 0
}
###############################################################################
