#!/bin/sh

echo "This script is being converted for Debian 7 from the CentoOS 7 version."
echo "You should customize this for your installation.  Modify the"
echo "IP address in the iptables to point to your home/work computer"
echo "to reduce the chance that a bad firewall will lock you out."
read -p "Not Finished Yet (press ENTER to continue)..." junk

PGUSER_HOME='/var/lib/postgresql'  # on centOS, I use /home/postgres
PGSQL_DATA='/var/lib/postgresql/9.1/main' #debian
PGSQL_BIN='/usr/lib/postgresql/9.1/bin/'
PGSQL_CONF='/etc/postgresql/9.1/main/postgresql.conf'


# This will start the postgre database.
# The databse error log is in /var/lib/pgsql/data/pg_log/

iptables --list
iptables --list-rules

# 
iptables -I INPUT 1 -s 204.13.129.0/24 -j ACCEPT
iptables -I INPUT 2 -m state --state new -m tcp -p tcp --dport 22 -j accept
iptables -I INPUT 3 -m state --state new -m tcp -p tcp --dport 443 -j accept
iptables -I INPUT 4 -m state --state new -m tcp -p tcp --dport 4430 -j accept
iptables -I INPUT 5 -m state --state new -m tcp -p tcp --dport 4431 -j accept
iptables -I INPUT 6 -m state --state new -m tcp -p tcp --dport 80 -j accept
iptables --policy INPUT DROP

################################################################################

cd /root
sudo -u postgres "${PGSQL_BIN}/postgres" -D "${PGSQL_DATA}"  > postgre-logfile.log 2>&1 &

#### centos: sudo -u postgres /usr/bin/postgres -D /var/lib/pgsql/data > logfile 2>&1 &

echo "The real log file is in ${PGSQL_DATA}/pg_log/"
echo "The next command should show running instances of postgres (postgre server):"
sleep 2

echo "The next line should show several instances of postgres:"
ps -A|grep " postgres$"

echo "If you are testing the experimental mix network,"
echo "be sure to prime the gpg agent by unlocking some files"
ls -l > /tmp/a.txt
#gpg --use-agent -e /tmp/a.txt

echo "Here is the fail2ban status"
##systemctl -l status fail2ban
echo "Use this command to see recent IP addresses blocked by fail2ban:"
ipset list
echo "check /var/log/fail2ban.log for messages from fail2ban."
