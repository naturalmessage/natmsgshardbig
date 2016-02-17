#!/bin/sh

# This will start the postgre database for debian 8
# The databse error log is in /var/log/postgresql/postgresql-9.4-main.log
# but also check /var/lib/pgsql/data/pg_log/
# and /var/lib/postgresql/postgres-bob.log
# or check the conf file shown in the output of
#    ps -Af|grep postgre

PGSQL_BIN=/usr/lib/postgresql/9.4/bin/postgres
PGSQL_CONF=/etc/postgresql/9.4/main/postgresql.conf
PGSQL_DATA=/etc/postgresql/9.4/main
PGUSER_HOME=/usr/lib/postgresql 

iptables --list
iptables --list-rules

# 
iptables -I INPUT -s 204.13.129.0/24 -j ACCEPT
# Allow established connections:
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
# ssh:
iptables -A INPUT -m state --state new -m tcp -p tcp --dport 22 -j ACCEPT
# postgre sql
iptables -A INPUT -m state --state new -m tcp -p tcp --dport 5432 -j ACCEPT
# https and https ports:
iptables -A INPUT -m state --state new -m tcp -p tcp --dport 80 -j ACCEPT
iptables -A INPUT -m state --state new -m tcp -p tcp --dport 443 -j ACCEPT

# Erlang connector for testing 
iptables -A INPUT -m state --state new -m tcp -p tcp --dport 8443 -j ACCEPT
# shard server ports:
iptables -A INPUT -m state --state new -m tcp -p tcp --dport 4430 -j ACCEPT
iptables -A INPUT -m state --state new -m tcp -p tcp --dport 4431 -j ACCEPT
iptables -A INPUT -m state --state new -m tcp -p tcp --dport 4432 -j ACCEPT
iptables -A INPUT -m state --state new -m tcp -p tcp --dport 4433 -j ACCEPT
iptables -A INPUT -m state --state new -m tcp -p tcp --dport 4434 -j ACCEPT
iptables -A INPUT -m state --state new -m tcp -p tcp --dport 4435 -j ACCEPT
iptables -A INPUT -m state --state new -m tcp -p tcp --dport 4436 -j ACCEPT
iptables -A INPUT -m state --state new -m tcp -p tcp --dport 4437 -j ACCEPT
iptables -A INPUT -m state --state new -m tcp -p tcp --dport 4438 -j ACCEPT
iptables -A INPUT -m state --state new -m tcp -p tcp --dport 4439 -j ACCEPT
iptables -A INPUT -m state --state new -m tcp -p tcp --dport 4440 -j ACCEPT
# Erlang stuff?
# the RPC setup for erlang?
iptables -A INPUT -p tcp --dport 111 -j ACCEPT
# I don't think I need to open 123 for the ntp/time
# server because I query another server as opposed
# to allowing somebody else to initialize a connection
# to my port 123.
#iptables -A INPUT -p udp --dport 123 -j ACCEPT

# SMTP server
# iptables -A INPUT -p tcp --dport 25 -j ACCEPT

# for multiple vpn servers
###old firewall-cmd  --zone=public --add-port=1194/tcp
iptables -A INPUT -p udp --dport 1194 -j ACCEPT
iptables -A INPUT -p udp --dport 1195  -j ACCEPT
iptables -A INPUT -p udp --dport 1196  -j ACCEPT
iptables -A INPUT -p tcp --dport 1194 -j ACCEPT
iptables -A INPUT -p tcp --dport 1195  -j ACCEPT
iptables -A INPUT -p tcp --dport 1196  -j ACCEPT


### ## vpn seemed to work without this
### iptables -A INPUT -p udp --dport 1194 -j ACCEPT
### iptables -A INPUT -i tun+ -j ACCEPT
### iptables -A OUTPUT -o tun+ -j ACCEPT
### iptables -A FORWARD -i tun+ -j ACCEPT
### iptables -A OUTPUT -p udp --sport 1194 -j ACCEPT
### 
###############################################################################
# The last iptables command is to APPEND a command to drop
# all other incomming:
# Default policy is to drop inbound action:
iptables --policy INPUT DROP
###############################################################################
###############################################################################
if !(systemctl status fail2ban); then
	echo "starting fail2ban"
	systemctl start fail2ban.service
fi

systemctl stop postgres # stop any automated server

###### ## "${PGSQL_BIN}/postgres" -D "${PGSQL_DATA}" -c config_file="${PGSQL_CONF}"
###### cd "${PGUSER_HOME}"
###### sudo -u postgres "${PGSQL_BIN}/postgres" -D "${PGSQL_DATA}"

cd "${PGUSER_HOME}"
sudo -u postgres ${PGSQL_BIN} -D "${PGSQL_DATA}" -c config_file="${PGSQL_CONF}" > /var/lib/postgresql/postgres-bob.log 2>&1 &

echo "The real log file is in /var/lib/pgsql/data/pg_log/"
echo "The next command should show running instances of postgres (postgre server):"
sleep 2
ps -A |grep postgres



echo "The next line should show several instances of postgres:"
ps -A|grep " postgres$"

echo ""
echo "BE SURE TO PRIME THE GPG AGENT BY UNLOCKING SOME FILES"
ls -l > /tmp/a.txt
#gpg --use-agent -e /tmp/a.txt

echo "Here is the fail2ban status"
systemctl -l status fail2ban

echo "Use this command to see recent IP addresses blocked by fail2ban:"
ipset list
if [ $? != 0 ]; then
	echo "Error he ipset list command failed.  Did you install ipset?"
	echo "ipset is needed for the default install of fail2ban to work"

fi
echo "check /var/log/fail2ban.log for messages from fail2ban."

