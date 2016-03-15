#!/bin/bash
#
# Setup notes and script for RaspberryPi with Raspbian/Debian 8.
# 
# To put this on a new Raspberry PI that runs Raspbian 8, login to the
# pi (the defulat user ID is pi and the default password is raspberry), 
# then you can run one of two things:
# 1) if you have a wired Ethernet connection and your Internet is
#    working on your pi:
#  curl -L --url http://tinyurl.com/glzjzyg -O
# 2) if your wifi device does not work by default, copy this script
#    to a USB stick and then put the USB stick into the Raspberry pi
#    to run the commands
# 3) If you can put the Raspberry pi boot SD card into your other computer
#    you could mount the drive and copy this script (and also setupNM-Deb8.sh)
#    to the /home/pi directory (if you know how to mount ext4 drives manually).
# 4) add a file (the name can not contain a ~ or a .) in /etc/sudoers.d/ with
#    with two lines like this (without the leading '#' and optionally include
#    another, custom user ID instead of 'super')
#       super ALL=(ALL:ALL) ALL
#       natmsg ALL=(ALL:ALL) ALL
# 5) add an entry for a root cron job in /var/spool/cron/crontabs/root 
#    that contains:
#       */5 * * * * /usr/bin/python3.4 /var/natmsg/monitor.py
# 6) modify /etc/ssh/sshd_config to set PermitRootLogin to say 'yes'.
###############################################################################
# to do
# 2) add code in the NM setup  to copy config scripts to new user IDs (template?).
#    .screenrc, .vimrc, .bash_profile, .profile
# 3) put this in my naturalmessage github.
###############################################################################
# Misc notes:
#
# The initial user id for Raspbian 8 is pi and the password is raspberry.
#
# The default Raspbian keyboard is for the UK, so here are a few key
# if you have a U.S. keyboard.  (note that I change keyboard layout below).
#               Key  | Produces
#             slash    #
#   right-alt tilde    | 
#
#
# After I used dd to put the initial boot image on the SD card, 
# * I used the parted command (and then 'resizepart 2') to expand the size of
#   the partition, then in this script, the file system is expanded to
#   fill the partition.
# * mount the new SD image on your laptop/main computer:
#   (In my case, my newly formatted SD card was in /dev/sdc, but
#   your device name might be different, use the lsblk command
#   to see what your device name is).
#     lsblk -a
#     sudo mkdir -p /media/SD
#     sudo mount /dev/sdc2 /media/SD
#     cp pisetup.sh /media/SD/home/pi
#     cp setupNM-Deb8.sh /media/SD/home/pi
#     cd /media/SD/home/pi
#     chown 1000:1000 *
#     cd ~
#     sync
#     umount /media/SD
#     eject /dev/sdc
###############################################################################

if [ ! "$EUID" = "0" ]; then
    echo "Error.  You must run this script as root."
    echo "Try rerunning like this:"
    echo "   sudo $0"
    exit 12
fi

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


if (confirm "Do you want to update passwords now? (y/n): "); then
	echo "########################################################################"
	echo "pi pi pi pi pi pi pi pi pi pi pi pi pi pi pi pi" 
	echo "You will now be prompted to enter a new password for the pi user ID."
	echo "Be sure that you remember this password."
	passwd pi

	read -p "Enter the user ID of a non-root user to add: " MY_UID
	useradd -m ${MY_UID}

	echo "Now you have to give you new user ID root privileges"
	vi /etc/sudoers

	echo "########################################################################"
	echo "root root root root root root root root root root root root root root root root" 
	echo "You will now be prompted to enter a new password for the root user ID."
	echo "Be sure that you remember this password."
	passwd root
fi

#############################################################
#  Optionally set keyboard to US.
#  In the future, you might need to first run this first: 
#      apt-get install keyboard-configuration
#
echo "The default keyboard layout for Raspbian is in British format."
echo "This causes problems for U.S. keyboards and other keyboards."
if (confirm "Do you want to change the keyboard now? (y/n): "); then
    dpkg-reconfigure keyboard-configuration
    setupcon

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
        resize2fs DEVNAME
    if [ $? != 0 ]; then
            echo "Oops. This command to resize the partition did not work.  You can try again later."
        else
            echo "Command ran OK."
        fi
    else
        resize2fs /dev/mmcblk0p2
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
./pi-wifi-setup.sh

###############################################################################
apt-get update && apt-get -y upgrade
apt-get -y install screen

# cryptsetup for encrypted disks
# There is a firmware problem in Feb 2016 that affects Raspberry Pi and its
# ability to run cryptsetup.
# If cryptsetup does not work, and your Pi is from early 2016, try this:

#   # one-time fix due to a bug that makes cryptsetup fail
#   # when trying to load aes-xts-plain64 cipher, March 2016.
#   echo "run this as root"
#   apt-get install rpi-update
#   rpi-update 0764e7d78d30658f9bfbf40f8023ab95f952bcad
apt-get -y install cryptsetup


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
