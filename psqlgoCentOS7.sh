#!/bin/sh

# This will start the postgre database.
# The databse error log is in /var/lib/pgsql/data/pg_log/


if !(systemctl status firewalld); then
	echo "starting firewalld"
	systemctl start firewalld
fi

# open port 80 temporarily for HTML pages
firewall-cmd --zone=public --add-service=http
# The 'permanent' options should already have
# 443 open, but this shouldn't hurt and it
# shows the syntax:
# open port 443 for https:
firewall-cmd --zone=public --add-service=https

# For testing, I will open port 4430.  I do not
# want the "--permanent" option below
firewall-cmd  --zone=public --add-port=4430/tcp
firewall-cmd  --zone=public --add-port=4431/tcp
firewall-cmd  --zone=public --add-port=4432/tcp

if !(systemctl status fail2ban); then
	echo "starting fail2ban"
	systemctl start fail2ban.service
fi

sudo -u postgres /usr/bin/postgres -D /var/lib/pgsql/data > logfile 2>&1 &

echo "The real log file is in /var/lib/pgsql/data/pg_log/"
echo "The next command should show running instances of postgres (postgre server):"
sleep 2
ps -A |grep postgres



echo "The next line should show several instanses of postgres:"
ps -A|grep " postgres$"

echo ""
echo "BE SURE TO PRIME THE GPG AGENT BY UNLOCKING SOME FILES"
ls -l > /tmp/a.txt
#gpg --use-agent -e /tmp/a.txt

ehco "Here is the fail2ban status"
systemctl -l status fail2ban
