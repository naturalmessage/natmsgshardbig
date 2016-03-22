#!/bin/bash
#
# Setup notes and script for RaspberryPi with Raspbian/Debian 8.
# 
# Tips for Novice Linux Users Who Want the Easiest Install Method
# ---------------------------------------------------------------
# The easiest way to run this (for Linux newbies) is to download an
# image of Raspbian that already has this script (and a couple other scripts)
# installed on it. If you have that image on your Raspberry Pi
# SD card, then...
#   1) Put the micro-SD card into your Raspberry Pi.
#      Plug in a USB Keyboard into a USB port.
#      Plug an Ethernet cable into your Pi and put the other end
#      into a working DSL modem (or whatever modem that gives you access
#      to the internet--avoid using wifi over the air).
#      Plug in a HDMI cable into the side of the Pi and put the
#      other end into and HDMI TV monitor or computer monitor
#      (I have an HDMI to DVI cable and it works with my old
#      computer monitor from 2008).
#   2) Insert the SD card that already contains the special image
#      of Raspbian that contains the Natural Message scripts.
#      The card goes
#      upside down, under the Pi on the end opposite from the USB
#      ports.  The card slot is spring loaded, so when it is nearly
#      inserted, you will feel a little spring tension, then it should
#      stick into place.  To Remove the card, press again, feel the
#      spring tension, and then the card should pop out. 
#   3) Plug in the power supply for the Raspberry Pi... you should see
#      a couple lights on the Pi light up.
#   4) log in with user id 'pi' (do not enter the quotes) and password
#      'raspberry' (do not enter the quotes).
#   5) You should automatically be in the /home/pi directory without
#      having to do anything to get there.  Now type this EXACTLY
#      as shown (without the leading #).
#        sudo ./pisetup.sh
#   6) Notes during pisetup.sh...
#      * When you get to the keyboard setup routine, the first screen
#        should detect the type of keyboard you have, then on the next
#        screen, use the arrow keys to scroll down to "Other" and press
#        ENTER.
#        On the next screen I use the arrow keys to select "English (US)"
#        then on the next screen I scroll to the top to selenct the regular
#        "English (US)" again, but you can select something that matches 
#        your language and keyboard.
#      * If you must use wifi for the initial setup, then say 'y' to
#        the prompt to set up wifi, then look at the output to see
#        the name of your wifi router--use the name that you would
#        normally see when you connect to it from another device...
#        It should be a name comprised of regualar letter and numbers
#        to form readable name (as oppsed to hex codes).
#
# Tips for Experienced Linux Users Who Want to Install this Manually
# ------------------------------------------------------------------
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
#    permissions set to 440
#    with two lines like this (without the leading '#' and optionally include
#    another, custom user ID instead of 'super')
#       super ALL=(ALL:ALL) ALL
#       natmsg ALL=(ALL:ALL) ALL
# 5) add an entry for a root cron job in /var/spool/cron/crontabs/root,
#    set permissions to 600, and set the content to contain:
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
#   to see what your device name is).  Example commands on Linux
#   follow.  If you don't have Linux, you could buy a pre-formatted
#   Raspbian card from Raspbian.org and then put a second SD card
#   in an external SD card reader on your Raspberry Pi and use
#   this to format the card that will have your special Natural Message
#   programs....
#     # first download Raspbian Lite from raspbian.org and unzip it:
#     unzip 2016-02-09-raspbian-jessie-lite.img.zip
#     lsblk -a # read this to find the device name of the SD card, 
#              # my card is at /dev/sdc
#     # 
#     dd if=2016-02-09-raspbian-jessie-lite.img of=/dev/sdc bs=4M
#     parted --align optimal /dev/sdc
#       (parted) unit MiB
#       (parted) print
#       (parted) resizepart 2 14000
#       (parted) print
#       (parted) q
#     lsblk -a
#     sudo mkdir -p /media/SD
#     sudo mount /dev/sdc2 /media/SD
#     sudo cp pisetup.sh /media/SD/home/pi
#     sudo cp pi-wifi-setup.sh /media/SD/home/pi
#     sudo cp setupNM-Deb8.sh /media/SD/home/pi
#     cd /media/SD/home/pi
#     chown 1000:1000 *
#     chmod 755 *.sh
#     # In the next example, I will optionally prepare for an
#     # additional user ID called 'super' in addition to the
#     # required user ID of 'natmsg'
#     echo "super ALL=(ALL:ALL) ALL" > /media/SD/etc/sudoers.d/natmsg
#     echo "natmsg ALL=(ALL:ALL) ALL" >> /media/SD/etc/sudoers.d/natmsg
#     chmod 600 /media/SD/etc/sudoers.d/natmsg
#     echo "*/5 * * * * /usr/bin/python3.4 /var/natmsg/monitor.py" > /media/SD/var/spool/cron/crontabs/root
#     chmod 600 /media/SD/var/spool/cron/crontabs/root
#     cd ~
#     sync
#     sudo umount /media/SD
#     sudo eject /dev/sdc
#    
#     # now find a directory that has free space and try this
#     df -h
#     cd /media/super/junk # or CD to your directory
#     dd if=/dev/sdc of=NatMsg-V001-2016-02-09-raspbian-jessie-lite.img bs=4M
#     zip NatMsg-V001-2016-02-09-raspbian-jessie-lite.img.zip NatMsg-V001-2016-02-09-raspbian-jessie-lite.img
# #######
#     # The following are notes to check the disk image by mounting
#     # it on a loop device
#     sudo parted  NatMsg-V001-2016-02-09-raspbian-jessie-lite.img
#     (parted) unit B
#     (parted) print
#     (parted) q
#     # The output shows the starting byte number for each partition.
#     # That information could be used to mount that partition later.
#     # In my case, the second partition started at byte 67108864.
#     #
#     # See which loop devices are in use
#     sudo losetup -l
#     sudo losetup /dev/loop0 NatMsg-V001-2016-02-09-raspbian-jessie-lite.img -o 67108864
#     # show some info about the device:
#     file -s /dev/loop0 
#     sudo mkdir -p /media/SD
#     sudo mount /dev/loop0 /media/SD/
#     # look at the disk image and check it.
#     umount /dev/loop0
#     losetup -d /dev/loop0
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
