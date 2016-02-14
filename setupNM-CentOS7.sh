#!/bin/bash

################################################################################
# Copyright 2015 Natural Message, LLC.
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

SQLITE_FILE="sqlite-autoconf-3080801.tar.gz"
PYTHON_VER="3.4.2"
DSTAMP=`date +"%Y%m%d%H%M%S"`

echo "Temp Note: Before starting, either copy these two files from the "
echo "other server or install them properly:"
echo "		cp pbkdf2_* /var/natmsg/"
echo "		cp RNCryptor.py /var/natmsg/"
echo " "
echo "This is a setup for the shard main server (directory server)"
echo "for CentOS 7."
echo
echo "First run:"
echo "	yum upgrade"
echo "	shutdown -r now"
echo "after you have done that. then proceede:"
read -p "..." junk
yum -y install vim screen httpd	lynx wget rsync libgpg-error-devel


echo "On Linode, gcc was not installed, and is needed"
echo "to compile python3."
yum -y install gcc

echo "bzip2 (bz2) is needed for the libgcrypt install."
# When I installed pyhthon 3.4 from source, the bz2 lib
# was there, but it called _bz2, which was not... try
# including the development version of bzip2 before compiling python.
yum -y install bzip2-devel

# While I'm at it, install other devel versions for the sake of python..
# (thanks to http://www.linuxtools.co/index.php/Install_Python_3.4_on_CentOS_7)
##yum groupinstall "Development tools"
yum install zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel libpcap-devel xz-devel
# I don't want the graphical tools...
# gdbm-devel  db4-devel tk-devel 


yum upgrade
if [ ! -d /root/noarch ]; then
	mkdir -p /root/noarch
fi

###
###
### devel headers needed for some python compile
yum -y install openssl-devel
###
########################################################################
echo ""
echo "You now have the option of installing SQLite from source."
echo "This is entirely optional, but helped to solve a problem"
echo "during an early release of Cent OS 7.  You might have no"
echo "need for this."
read -p "Do you want to install SQLite from source? (y/n): " MENU_CHOICE
case $MENU_CHOICE in
	'n'|'N')
		MENU_CHOICE='n';;
	'y'|'Y')
		MENU_CHOICE='y';;
esac

if [ "${MENU_CHOICE}" = "y" ]; then
	# Install sqlite source in an attempt to fix a problem
	# with Python 3 sqlit module
	if [ ! -d /root/noarch ]; then
		mkdir -p /root/noarch
	fi
	cd /root/noarch
	wget https://sqlite.org/2015/${SQLITE_FILE}
	
	gunzip ${SQLITE_FILE}
	## untar the filename with ".gz"	dropped:
	tar -xf ${SQLITE_FILE%%.gz}
	
	if [ -d ${SQLITE_FILE%%.tar.gz} ]; then
		cd ${SQLITE_FILE%%.tar.gz}
	else
		echo "ERROR, the SQLite directory was not found."
		exit 129
	fi
	
	./configure
	make
	make install
fi

########################################################################
read -p "Do you want to install Python3 from source? (y/n): " MENU_CHOICE
case $MENU_CHOICE in
	'n'|'N')
		MENU_CHOICE='n';;
	'y'|'Y')
		MENU_CHOICE='y';;
esac

if [ "${MENU_CHOICE}" = "y" ]; then
	###
	###
	###
	if [ ! -d /root/noarch ]; then
		mkdir -p /root/noarch
	fi
	cd /root/noarch
	if [	-f Python-${PYTHON_VER}.tgz ]; then
		echo "The Python 3 source file already exists.	Do you want to"
		read -p "KEEP that version? " MENU_CHOICE
		case $MENU_CHOICE in
			'n'|'N')
				MENU_CHOICE='n';;
			'y'|'Y')
				MENU_CHOICE='y';;
		esac
		
		if [	"${MENU_CHOICE}" = "n" ]; then
			rm Python-${PYTHON_VER}.tgz
		fi
	fi

	if [ ! -f Python-${PYTHON_VER}.tgz ]; then
		# The Python file is not already here, so download it...
		wget https://www.python.org/ftp/python/${PYTHON_VER}/Python-${PYTHON_VER}.tgz
		tar xf Python-${PYTHON_VER}.tgz
	fi

	if [	-d Python-${PYTHON_VER} ]; then
		cd Python-${PYTHON_VER}
	else
		echo "ERROR, the Python directory was not found after untarring it."
		exit 123
	fi
	
	
	# Do not change the install path unless you know what you are doing.
	# On some systems, overwriting gpg with the new version can
	# prevent the system from booting.
	./configure --prefix=/usr/local --enable-shared
	make
	make install
	# A python3 library is not in the default path,
	# so add it like this:
	echo /usr/local/lib >> /etc/ld.so.conf.d/local.conf
	ldconfig
fi

############################################################
############################################################
echo "Installing setuptools (ez_setup) from source"
wget https://bootstrap.pypa.io/ez_setup.py -O -
python3 ez_setup.py
############################################################
############################################################
############################################################
############################################################


read -p "Do you want to install PostgreSQL? (y/n): " MENU_CHOICE
case $MENU_CHOICE in
	'n'|'N')
		MENU_CHOICE='n';;
	'y'|'Y')
		MENU_CHOICE='y';;
esac

if [	"${MENU_CHOICE}" = "y" ]; then
	echo "My centos 7 has an install for almost the current postrgre (in late 2014),"
	echo "so I will use it."
	yum -y install postgresql-server postgresql-libs	postgresql-contrib postgresql-plpython
	
	echo 
	echo "When prompted, enter the password for the postgres user ID"
	passwd postgres
	
	echo "If installed from postgre, the command is:"
	whereis pg_ctl
	if [	-d /var/lib/pgsql/data ]; then
		if [ ! -d /var/lib/pgsql/data/base ]; then
			sudo -u postgres /usr/bin/pg_ctl -D /var/lib/pgsql/data initdb
		else
			echo "It looks like the datbase was already initalized in /var/lib/pgsql/data"
		fi
	else
		echo 'ERROR. there is no pg data directory in the expected place: /var/lib/pgsql/data'
		read -p "..." junk
	fi
	
	#-------------------------------------
	# one-time setup for postgres because it often
	# complains about permissions
	dd='/home/postgres/shard/sql/prod'
	if [ ! -d ${dd} ]; then
		mkdir -p /home/postgres/shard/sql/prod/dirsvr
		mkdir -p /home/postgres/shard/sql/prod/functions
		mkdir -p /home/postgres/shard/sql/prod/shardsvr
		mkdir -p /home/postgres/shard/sql/prod/sysmon
	fi
	chown -R postgres:postgres /home/postgres/
	chmod -R 700 /home/postgres/shard/
	
	# start the server preffereably running in 'screen'
	cd /home/postgres
	sudo -u postgres /usr/bin/postgres -D /var/lib/pgsql/data > logfile 2>&1 &
	
	
	
	
	### echo "This will attempt to edit the /var/lib/pgsql/data/postgresql.conf"
	
	# THIS MIGHT BE WRONG -- JUST RUN ON 127.0.0.1 -- DEFAULT
	MY_IP=$(ifconfig eth0|grep "inet "|tr -s ' '|cut -d ' ' -f 3|cut -d ':' -f 2)
	
	# Make a backup of the config before modifying it.
	
	DSTAMP=`date +"%Y%m%d%H%M%S"`
	############################################################
	echo "In the full Cent OS 7, you can install psycopg from yum,"
	echo "but I don't see it in Linode, and it doesn't work with"
	echo "python3 anyway, so get from source."
	
	if [ ! -d /root/noarch ]; then
	mkdir -p /root/noarch
	fi
	cd /root/noarch
	wget https://pypi.python.org/packages/source/p/psycopg2/psycopg2-2.5.4.tar.gz
	wget https://pypi.python.org/packages/source/p/psycopg2/psycopg2-2.5.4.tar.gz.asc # sig
	
	md5_check=$(openssl dgst -md5 psycopg2-2.5.4.tar.gz|cut -d ' ' -f 2)
	if [	"${md5_check}" = "25216543a707eb33fd83aa8efb6e3f26" ]; then
		echo "good md5"
	else
		echo "BAD MD5 for psycopg"
		read -p "..." junk
	fi
	
	# PGP but I don't have the pubic key
	gpg --verify psycopg2-2.5.4.tar.gz.asc psycopg2-2.5.4.tar.gz
	
	# for libpq-fe.h, install the devel version of libpqxx
	yum -y install libpqxx-devel
	gunzip psycopg2-2.5.4.tar.gz
	tar -xf psycopg2-2.5.4.tar
	cd psycopg2-2.5.4
	python3 setup.py	install
	
fi
# end of postgres install

############################################################
############################################################
############################################################
# Get EPEL so that I can get fail2ban for CentOS 7.
# Look in this directory:	https://dl.fedoraproject.org/pub/epel
cd /root
wget https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7


# fail2ban on CentOS7 uses firewalld and ipset, which should be installed,
# but double check
yum -y install ipset firewalld

rpm -Uvh https://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm
yum install fail2ban

if [ ! -f /etc/fail2ban/jail.local ]; then
	cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
fi

# Get the special conf files so that fail2ban 
# can use the new firewall-cmd command
# to close the firewall
# see https://apuntesderoot.wordpress.com/2014/02/27/configure-fail2ban-in-fedora-20-to-use-firewall-cmd-and-ipset/
if [ ! -f /etc/fail2ban/action.d/firewallcmd-ipset.conf ]; then
	echo "The firewallcmd-ipset.conf command is missing"
	cd /etc/fail2ban/action.d
	wget https://github.com/fail2ban/fail2ban/blob/master/config/action.d/firewallcmd-ipset.conf
	wget https://github.com/fail2ban/fail2ban/blob/master/config/action.d/firewallcmd-new.conf
fi

# alter the /etc/fail2ban/jail.conf file to change action to "action = firewallcmd-ipset"
# TO DO


# run it
systemctl restart fail2ban.service

echo "Now you have to edit the /etc/fail2ban/jail.local"
echo "see https://miceliux.com/blog/2014/03/25/fail2ban-0-9/"
echo "file to add 'enabled = true' to a few parts, including ssh."
echo "Your status should look something like this:"
echo "		Status"
echo "		|- Number of jail:			3"
echo "		- Jail list:	 selinux-ssh, sshd, sshd-ddo"
echo " "
read -p "Press a key to continue..." junk
# check it -- should see some jails??
fail2ban-client status

echo "use this command to see the ipset list of bad IP"
echo "ipset list"
ipset list
echo "Check /var/log/fail2ban.log for errors runign these jails."

echo "############################################################"
echo "I need to set up a cron job to purge log files -- ideally log files are to a RAM drive "
echo "or sent to a difrerent computer to an encrypted drive."

############################################################
############################################################
#	CherryPi
# There is a cherrypy and cherrypy2 install via EPEL for CentOS 7,
# but I think I need cherrypy3.
yum -y install hg 
############################################################
############################################################

# I am havinga problem with _sqlite3 python being missing
#yum -y install sqlite3-dbf
cd /usr/local/lib/python3.4/lib-dynload
ln /usr/lib64/python2.7/lib-dynload/_sqlite3.so /usr/local/lib/python3.4/lib-dynload/_sqlite3.so
mkdir -p /root/noarch/CherryPySource
cd /root/noarch/CherryPySource
hg clone https://bitbucket.org/cherrypy/cherrypy
cd cherrypy
python3 setup.py install
####
# gpg agent
cat >> ~/.profile <<EOF
agent_check=$(ps -A|grep " gpg[-]agent$")
if [	-z "${agent_check}" ]; then
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

cat <<EOF > /root/.screenrc
shelltitle "zz%t%"
hardstatus on
hardstatus alwayslastline
hardstatus string "%{.bW}%-w%{.rW}%n %t%{-}%+w %=%{..G} %H %{..Y} %m/%d %C%a "
#hardstatus string "%t%"
EOF
############################################################
############################################################
############################################################
natmsg_tst=$(cat /etc/passwd|grep '^natmsg[:]')
if [ -z "${natmsg_tst}" ]; then
	useradd --create-home	-s /bin/bash natmsg 
	echo " "
	echo " "
	echo "You will now be prompted to enter a password for the natmsg"
	echo "user ID.	Use a good password because hackers will know that"
	echo "you have a natmsg user ID and might try to crack the password."
	read -p '...' junk
	passwd natmsg
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
chmod 500 /var/natmsg/private

if [ ! -d /var/natmsg/shards ]; then
	mkdir /var/natmsg/shards
fi
chown natmsg:natmsg /var/natmsg/shards
chmod 600 /var/natmsg/shards

if [ ! -d /var/natmsg/html ]; then
	mkdir /var/natmsg/html
fi
chown natmsg:natmsg /var/natmsg/html
chmod 500 /var/natmsg/html

if [ ! -d /var/natmsg/conf ]; then
	mkdir /var/natmsg/conf
fi
chown natmsg:natmsg /var/natmsg/conf
chmod 500 /var/natmsg/html

if [ ! -d /var/natmsg/webmaster ]; then
	mkdir /var/natmsg/webmaster
fi
chown natmsg:natmsg /var/natmsg/webmaster
chmod 600 /var/natmsg/webmaster


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
# ntpdate will disappear, but it works for now
yum install ntpdate
# sync the time
ntpdate 2.fedora.pool.ntp.org

chown -R natmsg:natmsg /var/natmsg
# # # # # # # ## # #
echo "to do: create a cron job to run /home/natmsg/python/monitor.py every 5 min"
echo "use crontab -e to edit a crontab"
rslt=$(crontab -l|grep monitor.py)
if [	-z "${rslt}" ]; then
	echo "*/5 * * * * /usr/bin/python3 /home/natmsg/python/monitor.py"
	echo "copy the line above with the mouse and prepare to paste it into crontab..."
	input -p "Press any key to continue ..." junk
	crontab -e
fi
#
# mail setup
touch	/var/mail/natmsg
chown natmsg:natmsg /var/mail/natmsg 

############################################################
############################################################
# RNCryptor - encryption package used by the client app.
# also used for PBKDF2 for password-strengthening
cd /var/natmsg
curl -L --url https://github.com/RNCryptor/RNCryptor-python/raw/master/RNCryptor.py > /var/natmsg/RNCryptor.py
chmod 644 RNCryptor.py

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

## get	grub2-mkpasswd-pbkdf2 for use to hash passwords:
yum -y install grub2-tools

###### the python pbkdf2 routine is painfully slow
###### try using the command line:
######	 grub2-mkpasswd-pbkdf2	-c 10000 -s ASDF1234WERDSFG356
######
#### python3.3 does not have pbkdf2 in hashlib yet 
#### 
###cd /root/noarch
###curl -L https://pypi.python.org/packages/source/p/pbkdf2/pbkdf2-1.3.tar.gz\#md5=40cda566f61420490206597243dd869f > pbkdf2-1.3.tar.gz
###gunzip pbkdf2-1.3.tar.gz
###tar -xf pbkdf2-1.3.tar
###cd pbkdf2-1.3
###python3 setup.py install
############################################################
#															OpenSSL for CherryPy
# The SSL certs can not have a password, so put tem
# in an ecryptfs directory
sudo yum install ecryptfs-utils gettext
# install libffi with headers:
yum -y install libffi-devel

#
# The pyopenssl install seemed to mess up the cryptography package, which
# is now trying to use libffi. so reinstall it
# Download: https://github.com/pyca/cryptography/archive/master.zip
cd /root/noarch
curl -L --url https://github.com/pyca/cryptography/archive/master.zip > crypto.zip

unzip crypto.zip
cd cryptography-master
python3 setup.py install --user
#

# openssl for cherrypy (note tested)
# For openssl, first download pyopenssl 
# from https://github.com/pyca/pyopenssl/archive/master.zip
cd /root/noarch
curl -L --url https://github.com/pyca/pyopenssl/archive/master.zip > pyopenssl.zip

unzip pyopenssl.zip
if [	-d pyopenssl-master ]; then
	cd pyopenssl-master
else
	echo "Error. The pyopenssl-master directory does not exist"
fi
python3 setup.py install --user
	#
#
# my install went to 
#	 /opt/python3/lib/python3.4/site-packages/pyOpenSSL-0.14-py3.4.egg
#

########################################################################
read -p "Do you want to generate a self-signed SSL certificate? (y/n): " MENU_CHOICE
case $MENU_CHOICE in
	'n'|'N')
		MENU_CHOICE='n';;
	'y'|'Y')
		MENU_CHOICE='y';;
esac

if [	"${MENU_CHOICE}" = "y" ]; then
	#
	# test it by running python3 and execute "from OpenSSL import SSL"
	#
	# Then create your ssl keys:
	# THESE FILES NEED TO BE ON AN ECRYPTFS DIRECTORY
	# THAT IS OWNED BY USER NATMSG.
	#	 # 
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
	openssl x509 -req -inform PEM -outform PEM -days 63 -in ca.csr -signkey ca.key -out ca.crt

	# You can run this to get information from your crt file:
	openssl x509 -text -in ca.crt # get info
	if [ ! -d /var/natmsg/private ]; then
		mkdir -p /var/natmsg/private
	fi
	chown -R natmsg:natmsg /var/natmsg/private
	chmod 700 /var/natmsg/private
	### add backup of old keys
	### add backup of old keys
	### add backup of old keys
	### add backup of old keys
	### add backup of old keys
	if [ -f /var/natmsg/private/ca.key ]; then
		# backup the old keys
		mv /var/natmsg/private/ca.key /var/natmsg/private/${DSTAMP}.ca.key
	fi

	if [ -f /var/natmsg/private/ca.csr ]; then
		# backup the old keys
		mv /var/natmsg/private/ca.csr /var/natmsg/private/${DSTAMP}.ca.csr
	fi

	if [ -f /var/natmsg/private/ca.crt ]; then
		# backup the old keys
		mv /var/natmsg/private/ca.crt /var/natmsg/private/${DSTAMP}.ca.crt
	fi
fi

#Test ssl here (no IPs allowed at the first one): https://www.ssllabs.com/ssltest/

############################################################
# The Requests lib for python comes from
# http://docs.python-requests.org/en/latest/user/install/#get-the-code
# and the downloaded directory looks something like this:
# kennethreitz-requests-359659c

cd /root/noarch
curl -L --url https://github.com/kennethreitz/requests/tarball/master > requests-master.tar.gz

gunzip requests-master.tar.gz 
tar -xf requests-master.tar
dir_name=$(ls -lotrd kennethreitz-requests* |tail -n 1|cut -d ' ' -f 9)
cd "${dir_name}"
##cd kennethreitz-requests-122c92e
python3 setup.py install



############################################################
# install libgcrypt and dependencies... used by nm_verify
# BE CAREFUL TO NOT INSTALL THE DEFAULT PINENTRY--IT WILL INSTALL GUI
# here is a list of current downloads from a mirror in Canada:
# http://gnupg.parentinginformed.com/download/index.html#libgpg-error
##
### In Dec 2014, CentOS7 still had libgcrypt 1.5.3 and for some reason
### it did not work with elliptic keys
## yum install libgcrypt-devel libksba-devel libassuan-devel

if [ ! -d /root/c/lib ]; then
	mkdir -p /root/c/lib
fi

cd /root/c/lib
######		
libgpgerr_ver="libgpg-error-1.17"
if [	-f ${libgpgerr_ver}.tar.bz2 ]; then
	read -p "The libgpg-error	source file already exists.	Do you want to DELETE that version? " MENU_CHOICE
	case $MENU_CHOICE in
		'n'|'N')
			MENU_CHOICE='n';;
		'y'|'Y')
			MENU_CHOICE='y';;
	esac

	if [	"${MENU_CHOICE}" = "y" ]; then
		rm ${libgpgerr_ver}.tar.bz2
	fi
fi

if [ ! -f ${libgpgerr_ver} ]; then
	wget ftp ftp://ftp.gnupg.org/gcrypt/libgpg-error/${libgpgerr_ver}.tar.bz2
	wget ftp://ftp.gnupg.org/gcrypt/libgpg-error/${libgpgerr_ver}.tar.bz2.sig
fi

if [	-d ${libgpgerr_ver} ]; then
	echo "The libgpgerr directory already exists.	 I will rename it."
	mv ${libgpgerr_ver} ${libgpgerr_ver}${DSTAMP}
fi

if [	-f ${libgpgerr_ver}.tar ]; then
	echo "The libgpgerr tar file already exists.	 I will rename it."
	mv ${libgpgerr_ver}.tar ${libgpgerr_ver}.tar.${DSTAMP}
fi

if ! bunzip2 "${libgpgerr_ver}.tar.bz2"; then
	echo "Error, failed to unzip the ${libgpgerr_ver}.tar.bz2"
else
	tar -xf "${libgpgerr_ver}.tar"

	cd "${libgpgerr_ver}" 
	if ! ./configure --enable-static --disable-shared; then
		echo "Error. failed to configure ${libgpgerr_ver}"
		exit 12
	else
		# the static lib is lib/libgpg-error/src/.libs/libgpg-error.a
		if ! make; then
			echo "Error. Failed to make libgpg-error, which is needed for libgcrypt"
			exit 144
		fi
	fi
fi

read -p "press a key to continue..."
########################################################################
if [ ! -d /root/c/lib ]; then
	mkdir -p /root/c/lib
fi

cd /root/c/lib
libgcrypt_ver="libgcrypt-1.6.2"
if [	-f ${libgcrypt_ver}.tar.bz2 ]; then
	read -p "The libgcrypt source file already exists.	Do you want to DELETE that version? " MENU_CHOICE
	case $MENU_CHOICE in
		'n'|'N')
			MENU_CHOICE='n';;
		'y'|'Y')
			MENU_CHOICE='y';;
	esac

	if [	"${MENU_CHOICE}" = "y" ]; then
		rm ${libgcrypt_ver}.tar.bz2
	fi
fi

if [ ! -f ${libgcrypt_ver}.tar.bz2 ]; then
	wget ftp://ftp.gnupg.org/gcrypt/libgcrypt/${libgcrypt_ver}.tar.bz2
	wget ftp://ftp.gnupg.org/gcrypt/libgcrypt/${libgcrypt_ver}.tar.bz2.sig
fi

if [	-d ${libgcrypt_ver} ]; then
	echo "The libgcrypt directory already exists.	 I will rename it."
	mv ${libgcrypt_ver} ${libgcrypt_ver}${DSTAMP}
fi

if [	-f ${libgcrypt_ver}.tar ]; then
	echo "The libgcrypt tar file already exists.	 I will rename it."
	mv ${libgcrypt_ver}.tar ${libgcrypt_ver}.tar.${DSTAMP}
fi

if	! bunzip2 ${libgcrypt_ver}.tar.bz2; then
	echo "Error.	Failed to unzip libgcrypt."
	exit 133
fi

tar -xf ${libgcrypt_ver}.tar
cd ${libgcrypt_ver}
## This needs to read the static version of libgpg-error to
## avoid confusion with the older version that might be in CentOS 7.
## The static library for libgpg-error is in /root/c/lib/libgpg-error-1.17/src/.libs/libgpg-error.a
##./configure --enable-static=libgcrypt,libassuan,libksba --disable-shared --with-libgpg-error-prefix=/root/c/lib/libgpg-error-1.17/src/.libs/libgpg-error.a
# try to point to static lib
export GPG_ERROR_LIBS=/root/c/lib/libgpg-error-1.17/src/.libs/
./configure --enable-static --disable-shared --with-libgpg-error-prefix=/root/c/lib/libgpg-error-1.17/src/.libs/libgpg-error.a
# The static library made by make with the static option is:
#	lib/libksba/src/.libs/libksba.a
if ! make; then
	echo "Error.	Failed to make libgcrypt."
	exit 133
fi

if [	-f	/root/c/lib/libgcrypt-1.6.2/src/.libs/libgcrypt.a ]; then
	echo "I now have a static library for libgcrypt that can be compiled into my other programs"
else
	echo "Error.	I did not find the static library for libgcrypt that can be compiled into my other programs"
fi


#############################################################
echo "the next part assumes that you have copied the sql into /home/postgres/shard/sql"
echo "hit CTL-c to quit or press a button to continue"
read -p "..." junk

if grep '^postgres[:]' /etc/passwd; then
	if [ ! -d /home/postres ]; then
		mkdir /home/postgres
		chown postgres:postgres /home/postgres
	fi

	if [ ! -d /home/postres/shard/sql ]; then
		mkdir -p /home/postgres/shard/sql
		chown -R postgres:postgres /home/postgres
	fi

	cd /home/postgres/shard/sql
	#sudo -u postgres psql sharddb -c "\i 0002create_tables.sql"
	#ftp://ftp.gnupg.org/gcrypt/pinentry/pinentry-0.9.0.tar.bz2
	#ftp://ftp.gnupg.org/gcrypt/pinentry/pinentry-0.9.0.tar.bz2.sig
fi
#############################################################
echo "the next part assumes that you have copied the sql into /home/postgres/shard/sql"
echo "hit CTL-c to quit or press a button to continue"
read -p "..." junk

cd /home/postgres/shard/sql
#sudo -u postgres psql sharddb -c "\i 0002create_tables.sql"

# 
echo "If you have not done so already, get the Natural Message SQL stuff for "
echo "/home/postgres/shard/sql/prod"
echo "then run: "
echo "     cd /home/postgres/shard/sql/prod/shardsv"
echo "     sudo -u postgres  ./0002create_db.sh"
echo "Then edit the password in 0010setup.sql"
echo "The run:"
echo "    sudo -u postgres shardsvrdb"
echo "You will be runnig inter active postgresql client"
echo "run these command to create the database:"
echo "    \\i 0010setup.sql"
echo "    \\i 0015shard_server.sql"
echo "    \\i 0016shard_server_big.sql"
echo "Use this command to get a list of the sql files in the functions subdirectory:"
echo "    \\! ls functions"
echo "The process/import those files:" 
echo "   \\i functions/can_shard_delete.sql"
echo "Do the same for the otin that directory.  That list might look like this:"
echo "  shard_burn.sql, shard_delete.sql, shard_expire.sql, shard_burn_big.sql"
echo "  shard_delete_db_entries.sqli,  shard_expire_big.sql,  shard_id_exists.sql"
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                