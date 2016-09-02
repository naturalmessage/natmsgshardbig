#!/bin/sh
#
###############################################################################
## Static IP for wired internet for the Raspberry pi.
#
# 4) restart networking:
#        systemctl restart networking
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
###############################################################################
RASPPI_STATIC_IP='10.0.0.20'
RASPPI_NETWORK='10.0.0.0'
RASPPI_BROADCAST='10.0.0.255'
RASPPI_NAMESVR1='192.168.0.1'
RASPPI_NAMESVR2='192.168.0.1' #user can override
RASPPI_GATEWAY='10.0.0.5'
SETTINGS_FNAME='/etc/network/interfaces'

DSTAMP=`date +"%Y%m%d%H%M%S"`
TMP_FNAME="/tmp/interfaces${DSTAMP}"
echo "############################################"
echo "Starting $0"
echo

if [ ! "$EUID" = "0" ]; then
    echo "Error.  You must run this script as root."
    echo "Try rerunning like this:"
    echo "   sudo $0"
    exit 12
fi

echo "Warning.  This is intended to set a fixed IP"
echo "on Raspbian 8 (based on Debian 8).  This might"
echo "not work on other systems."
echo ""
read -p "Press ENTER to continue..." junk

# Comment out the old iface setting for eth0
# and put it in a temp file:
cat ${SETTINGS_FNAME} | sed -e 's/^iface eth0/#iface eth0/' > /tmp/interfaces${DSTAMP}
if [ ! $? = 0 ]; then
    echo "ERROR.  I could not copy the modified /etc/interfaces file"
    echo "to a temp file."
    exit
fi


OK='no'
while [ ${OK} != 'yes' ]; do
    # Enter ip in the 10.0.0.0/24 range, otherwise you can
    # alter this script
    echo "STATIC IP FOR YOUR RASPBERRY PI in the 10.0.0.0/24 range..." 
    echo "An example value would be ${RASPPI_STATIC_IP}"
    echo "The first part should be 10.0.0"
    read -p "Enter the desired static IP for the Raspberry Pi:" RASPPI_STATIC_IP
    echo "You entered ${RASPPI_STATIC_IP}"
    if confirm "Do you want to keep this value (y/n): "; then
        OK='yes'
    fi 
done

OK='no'
while [ ${OK} != 'yes' ]; do
    echo "FIRST IP FOR THE NAME SERVERS"
    echo "Nameservers translate domain names to IP address,"
    echo "Such as translating yahoo.com to 98.139.183.24."
    echo "You should look at the Internet settings on one of your"
    echo "home computers to find the nameserver, but if you"
    echo "can not find any values, just enter:"
    echo "${RASPPI_NAMESVR1}"
    read -p "Enter ONE IP for the first nameserver for the Raspberry Pi:" RASPPI_NAMESVR1
    echo "You entered ${RASPPI_NAMESVR1}"

    if confirm "Do you want to keep this value (y/n): "; then
        OK='yes'
    fi 
done

OK='no'
while [ ${OK} != 'yes' ]; do
    echo "SECOND IP FOR THE NAME SERVERS"
    echo "You can not add another nameserver.  If you don't know"
    echo "one, try entering the IP for your DSL router:"
    echo "${RASPPI_NAMESVR2}"
    read -p "Enter ONE IP for the first nameserver for the Raspberry Pi:" RASPPI_NAMESVR2
    echo "You entered ${RASPPI_NAMESVR2}"

    if confirm "Do you want to keep this value (y/n): "; then
        OK='yes'
    fi 
done


OK='no'
while [ ${OK} != 'yes' ]; do
    echo "GATEWAY IP FOR YOUR RASPBERRY PI"
    echo "This script assumes that the computer that"
    echo "already has access to the Internet has a static IP."
    echo "This script assumes that you are using IPs in the"
    echo "range 10.0.0.0 through 10.0.0.255."
    read -p "Enter ONE IP for the first nameserver for the Raspberry Pi:" RASPPI_GATEWAY
    echo "You entered ${RASPPI_GATEWAY}"

    if confirm "Do you want to keep this value (y/n): "; then
        OK='yes'
    fi 
done
# Append the static IP information 
cat <<EOF > "${TMP_FNAME}"
allow hot-plug eth0
iface eth0 inet static
    address ${RASPPI_STATIC_IP}
    netmask 255.255.255.0   
    network ${RASPPI_NETWORK}
    broadcast ${RASPPI_BROADCAST}
    gateway ${RASPPI_GATEWAY}
dns-nameservers ${RASPPI_NAMESVR1}
dns-nameservers ${RASPPI_NAMESVR2}
EOF

# 
cp "${TMP_FNAME}" ${SETTINGS_FNAME}
if [ ! $? = 0 ]; then
    echo "ERROR.  I could not copy the modified interfaces file"
    echo "(${TMP_FNAME}) back to the original location" 
    echo "(${SETTINGS_FNAME})"
    exit 17
fi

# Note: there does not seem to be a need to modify the
# /etc/resolv.conf file.

# Restart networking to apply the changes
ip link set eth0 down
systemctl restart networking
if [ ! $? = 0 ]; then
    echo "ERROR.  Could not restart networking services."
    exit 19
fi
ip link set eth0 up

