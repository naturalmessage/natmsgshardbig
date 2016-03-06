#!/bin/sh
#
# Setup notes and script for RaspberryPi with Raspbian/Debian 8.
# 
# To put this on a new Raspberry PI that runs Raspbian 8,
# you can do one of the following:
# (the defulat user ID is pi and the default password is password), 
#
# 1) If I make a custom Raspbian image that is pre-sized to fit your
#    SD card (e.g, one version for 8GB card, another for a 16GB card...),
#    then use that (if you are not familiar with altering partitions
#    on Linux disks).
# 2) If you can put the Raspberry pi boot SD card into your other computer,
#    you could mount the Raspbian drive and copy this script to the /home/pi directory
#    (if you know how to mount ext4 drives manually), then when you boot
#    your Raspberry Pi with that disk, the file is already in the home
#    directory.
# 3) If you already have a working Internet connection on your Raspberry Pi,
#    (such as if you have a wired Ethernet connection on your Pi), try
#    running this:
#       curl -L --url http://tinyurl.com/glzjzyg -o pisetup.sh
#       chmod 755 pisetup.sh
#       sudo ./pisetup.sh
# 4) If your wifi device does not work by default, copy this script
#    to a USB stick and then put the USB stick into the Raspberry pi
#    to run the commands (this might be a bit dangerous because USB is
#    vulnerable to hardware-level hacks).
###############################################################################
# to do
# 2) add code in the NM setup  to copy config scripts to new user IDs (template?).
#    .screenrc, .vimrc, .bash_profile, .profile
# 3) put this in my naturalmessage github.
###############################################################################
# Misc notes:
#
# The initial user id for Raspbian 8 is pi and the password is password.
#
# The default Raspbian keyboard is for the UK, so here are a few key
# if you have a U.S. keyboard.  (note that I change keyboard layout below).
#               Key  | Produces
#             slash    #
#   right-alt tilde    | 
#
#
# When I used dd to put the initial boot image on the SD card, 
# I used parted to expand the size of the partition, .  Maybe you should
# reboot after repartitioning.
# # parted
# (parted) unit MB
# (parted) print
# (parted) resizepart 2 15924
#
###############################################################################
################################################################################
# Miscellaneous functions
DSTAMP=`date +"%Y%m%d%H%M%S"`

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

################################################################################
# ON FIRST LOGIN, ADD A NEW USER, GIVE IT ROOT PRIV, SET THE ROOT PW!!!

echo "########################################################################"
echo "pi pi pi pi pi pi pi pi pi pi pi pi pi pi pi pi" 
echo "You will now be prompted to enter a new password for the pi user ID."
echo "Be sure that you remember this password."
if (confirm "Do you want to reset the password for the pi user ID? (y/n): "); then
  sudo passwd pi
fi

if (confirm "Do you want to add a new user ID? (y/n): "); then
    read -p "Enter the user ID of a non-root user to add: " MY_UID
    sudo useradd -m ${MY_UID}

    echo "Now you have to give you new user ID root privileges"
    sudo vi /etc/sudoers
fi

echo "########################################################################"
echo "root root root root root root root root root root root root root root root root" 
echo "You will now be prompted to enter a new password for the root user ID."
echo "Be sure that you remember this password."
if (confirm "Do you want to reset the password for the root user ID? (y/n): "); then
    sudo passwd root
fi

#############################################################
#  Optionally set keyboard to US.
#  In the future, you might need to first run this first: 
#      apt-get install keyboard-configuration
#
echo "The default keyboard layout for Raspbian is in British format."
echo "This causes problems for U.S. keyboards and other keyboards."
if (confirm "Do you want to change the keyboard now? (y/n): "); then
    sudo dpkg-reconfigure keyboard-configuration
    sudo setupcon

    echo
    echo "Note that if you are running inside 'screen' that the changes will"
    echo "note be effective until you quit 'scren'."
    echo "You should probably reboot so that the new keyboard layout is used."
fi

#############################################################
# Resize the file system, this assumes that you used parted
# to enlarge the partition when the boot disk was created.

CHK_PARTITION=$(lsblk | grep mmcblk0p2)
clear
echo "You now have an opportunity to make your Raspbian boot partition bigger."
echo "You would do this only for a new Raspbian SD card."
echo "If you don't know what this means, choose 'y' at the next prompt."
echo
if (confirm "Do you want to resize your boot partition to fill the physical storage device? (y/n): "); then

    if [ -z "${CHK_PARTITION}" ]; then
      # I did not see the expected device name. Prompt the user
        echo "I will now display some information about attached drives."
        lsblk -a
        echo 
        echo "Using the info above, you can resize the new Raspbian disk image"
        echo "so that it fills your SD card and gives you more usable storage space."
      echo "You generally want to use the last device shown above, then add '/dev/'"
      echo "in front of that.  If the list above says mmcblk0p2, then you would enter"
        echo "   /dev/mmcblk0p2"
        read -p "Enter the full device name to resize, starting with /dev/: " DEVNAME
        sudo resize2fs DEVNAME
    if [ $? != 0 ]; then
            echo "Oops. This command to resize the partition did not work.  You can try again later."
        else
            echo "Command ran OK."
        fi
    else
        sudo resize2fs /dev/mmcblk0p2
    if [ $? != 0 ]; then
            echo "Oops. This command to resize the partition did not work.  You can try again later."
        else
            echo "Command ran OK."
        fi
    fi
fi

#############################################################
###         WIFI SETUP
# my linksys wifi thing does not work by default????.
echo
echo "Note: the wifi setup here assumes that you will connect to "
echo "exactly one wifi signal, but you could rerun this to change to "
echo "a new connection."
if (confirm "Do you want to connect to a wifi network? (y/n): "); then
    # try to bring up wifi:
    sudo ifconfig wlan0 up

    # Get a list of channels

    # sudo iwlist scan | less
    iwlist scan|grep 'ESSID\|Address\|wlan'

    echo "Note that there might be hidden networks not shown in the list above."
    read -p "Enter and ESSID from the list above to connect to that wifi: " WIFI_ESSID
    sudo iwconfig wlan0 essid "${WIFI_ESSID}"

    sudo ip link show wlan0
    sudo ip link set wlan0 up

    # check wlan0
    echo "=== If your wifi is set up, you should see the name of your wifi"
    echo "=== network in the ESSID of the following report:"
    iwconfig wlan0

    # See if you are connectd to the Internet
    #    (it will return a text status message)
    sudo /sbin/iw wlan0 link

    # one-time setup... create a conf file for the
    # wireless network:

    # make an archive copy of the wpa config file:
    sudo cp -n /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant${DSTAMP}.conf

    CONF_CHECK=$(cat /etc/wpa_supplicant/wpa_supplicant.conf | grep "${WIFI_ESSID}")
    if [ -n "${CONF_CHECK}" ]; then
        echo "WARNING.  You already have an entry for this wifi in /etc/wpa_supplicant/wpa_supplicant.conf"
        echo "I will overwrite that.  You can always restore it by renaming the backup file in that same directory."
    fi

    # I am assuming only one wifi.  You could change the '>' to '>>' to append this wifi
    echo "Enter the passphrase for your wifi network (${WIFI_ESSID}):"
    sudo wpa_passphrase "${WIFI_ESSID}" > /etc/wpa_supplicant/wpa_supplicant.conf

    # run it, where -D specifies the wireless driver.
    echo "Starting the WPA supplicant (the wifi password thingy) now."
    sudo wpa_supplicant -B -D wext -i wlan0 -c /etc/wpa_supplicant/wpa_supplicant.conf

    # you should probably just reboot now and check ifconfig after rebooting.

    # check for connection again:
    # (it should show a dozen lines about the ESSID, signal, and other info about the connection)
    echo "Here is some info about the wifi connection.  It should show information about"
    echo "the connection if you are connected:"
    sudo /sbin/iw wlan0 link
fi

###############################################################################


# get the debian key for upgrades etc.
curl  --max-time 300 --retry 5 --retry-delay 20  --url https://ftp-master.debian.org/keys/archive-key-8.asc -O
curl  --max-time 300 --retry 5 --retry-delay 20  --url https://ftp-master.debian.org/keys/archive-key-8-security.asc -O

apt-key add - < archive-key-8.asc
apt-key add - < archive-key-8-security.asc

# Get the Nat Msg shard server setup and run it.
curl  --max-time 900 --retry 5 --retry-delay 40   --url https://raw.githubusercontent.com/naturalmessage/natmsgshardbig/master/setupNM-Deb8.sh -O
chmod 755 setupNM-Deb8.sh
./setupNM-Deb8.sh
