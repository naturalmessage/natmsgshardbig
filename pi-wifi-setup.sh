#!/bin/bash

if [ ! "$EUID" == "0" ]; then
    echo "Error.  You must run this script as root."
    echo "Try rerunning like this:"
    echo "   sudo $0"
    exit 12
fi

##### set the /etc/network/interfaces file to look like this
#   #  (without the leading '#   '):
#   # interfaces(5) file used by ifup(8) and ifdown(8)
#
#   # Please note that this file is written to be used with dhcpcd
#   # For static IP, consult /etc/dhcpcd.conf and 'man dhcpcd.conf'
#
#   # Include files from /etc/network/interfaces.d:
#   source-directory /etc/network/interfaces.d
#
#   auto lo
#   iface lo inet loopback
#
#   iface eth0 inet manual
#
#   allow-hotplug wlan0
#   iface wlan0 inet dhcp
#       wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
#
#   allow-hotplug wlan1
#   iface wlan1 inet manual
#       wpa-conf /etc/wpa_supplicant/wpa_supplicant.conf
#####

###################### the wpa_supplicant conf file needed the extra options
#   # reading passphrase from stdin
#   network={
#   ssid="CenturyLink9999"
#   psk=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
#   # Protocol type can be: RSN (for WP2) and WPA (for WPA1)
#   proto=WPA
#
#   # Key management type can be: WPA-PSK or WPA-EAP (Pre-Shared or Enterprise)
#   key_mgmt=WPA-PSK
#
#   # Pairwise can be CCMP or TKIP (for WPA2 or WPA1)
#   pairwise=TKIP
#
#   #Authorization option should be OPEN for both WPA1/WPA2 (in less commonly used are SHARED and LEAP)
#   auth_alg=OPEN
#   }


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



echo "Note: the best setup for a Raspberry Pi Natural Message shard server"
echo "is to connect with the Ethernet cable to the back of your Internet"
echo "router as opposed to connecting over the wifi signal."
echo "If you need to use wifi for some reason, you can continue."
if (confirm "Do you want to connect to a wifi network? (y/n): "); then
    # try to bring up wifi:
    ifconfig wlan0 up

    # Get a list of channels

    # sudo iwlist scan | less
    iwlist scan|grep 'ESSID\|Address\|wlan'

    if (confirm "Do you see your wifi network in the list? (y/n): "); then
        echo 
        echo "Note that there might be hidden networks not shown in the list above."
        echo "On the next line, enter the ESSID, which is usually letters and numbers as opposed to hex codes."
        read -p "Enter and ESSID from the list above to connect to that wifi: " WIFI_ESSID
        iwconfig wlan0 essid "${WIFI_ESSID}"

        ip link show wlan0
        ip link set wlan0 up

        # check wlan0
        iwconfig wlan0

        # See if you are connectd to the Internet
        #    (it will return a text status message)
        /sbin/iw wlan0 link

        # one-time setup... create a conf file for the
        # wireless network:

        # make an archive copy of the wpa config file:
        cp -n /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant${DSTAMP}.conf

        CONF_CHECK=$(cat /etc/wpa_supplicant/wpa_supplicant.conf | grep "${WIFI_ESSID}")
        if [ -n "${CONF_CHECK}" ]; then
            echo "WARNING.  You already have an entry for this wifi in /etc/wpa_supplicant/wpa_supplicant.conf"
            echo "I will overwrite that.  You can always restore it by renaming the backup file in that same directory."
        fi

        # Create a wpa config file using the wpa_passphrase program
        # plus a little hack to add extra options that I needed during testin.
        # This is a one-time setup so that this computer can connect automatically to a wifi network
        # (assuming that you have a good signal and the correct password).
        # It is possible that the user will have to edit the additional options
        # that I append to the .conf file.
        # I am assuming only one wifi.  You could change the '>' to '>>' to append this wifi
        echo "Enter the passphrase for your wifi network (then press ENTER):"
        wpa_passphrase "${WIFI_ESSID}" |sed -e 's/^[}]//' > /etc/wpa_supplicant/wpa_supplicant.conf

# Append some options to the wpa conf file:
cat << EOF >> /etc/wpa_supplicant/wpa_supplicant.conf
# Protocol type can be: RSN (for WP2) and WPA (for WPA1)
proto=WPA

# Key management type can be: WPA-PSK or WPA-EAP (Pre-Shared or Enterprise)
key_mgmt=WPA-PSK

# Pairwise can be CCMP or TKIP (for WPA2 or WPA1)
pairwise=TKIP

#Authorization option should be OPEN for both WPA1/WPA2 (in less commonly used are SHARED and LEAP)
auth_alg=OPEN
}
EOF

        chmod 600 /etc/wpa_supplicant/wpa_supplicant.conf
        # run it, where -D specifies the wireless driver.
        wpa_supplicant -B -D wext -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf


        # you should probably just reboot now and check ifconfig after rebooting.

        # check for connection again:
        # (it should show a dozen lines about the ESSID, signal, and other info about the connection)
        echo "Here is some info about the wifi connection.  It should show information about"
        echo "the connection if you are connected:"
        /sbin/iw wlan0 link

        echo "you might need to reboot now."
    else
        echo "You should check your wifi device and try again."
        echo "If you have a weak signal, then your wifi connection might be unreliable."
        read -p "Press Enter to see partial output from the iwlist scan command that shows signal strength..." junk
        iwlist scan|grep ' Address[:]\|ESSID\|Signal'
        echo "====== note, high quality values are better"
    fi
fi
# ip link set wlan0 up
echo "================= here is some info about wlan0 wifi connection:"
/sbin/iw wlan0 link
