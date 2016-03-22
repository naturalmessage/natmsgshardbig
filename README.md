Overview
--------
This is the "big" Natural Message shard server that saves shards to disk as
opposed to in a database.  The idea is to allow people to run their own servers
to protect their own messages, the messages of their friends, or the messages
of the general public.

These servers can be configured to hold "password shards" (which are tiny files
that hold one part of a larger encryption key) or "big shards" (which might
hold 1-5 MB pieces of files (the pieces of files are called "shards").  The
shard servers hold chunks of information for messages that are sent via Natural
Message, and the general idea is for the end-user's app to encrypt the files,
split the encrypted file and the (double encrypted) encryption keys into
pieces, distribute those pieces across many servers, prevent the central
"directory server" from ever having keys to read any files, and allow the
recipient to collect all those "burn on read" pieces to reconstruct the
message.  All of the shards are burn on read, meaning that after somebody reads
the shard, the server destroys all copies of it.  Also note that the server
operator enters a password when the server starts so that the shards are
encrypted yet again before being saved to disk.

This is not quite ready, but if you want to run a shard server, contact
naturalmessage@fastmail.nl for free help.

The preferred way to run a shard server is for people to run a "password shard
server" on a Raspberry Pi (that means install this program and set an option in
the configuration file so that it will accept only tiny files (such as under
300 bytes).  By running a password server, it is very unlikely that the
Raspberry Pi will ever hold any actual content that is objectionable.

The best way to run you Raspberry Pi is to make it a dedicated server without
adding any other software or using it for any purpose other than a shard
server.

If you are not familiar with running a Linux machine from the command line,
there will soon be an install image that will make it easier to run your own
shard server.  The Raspberry Pi install image will contain pisetup.sh,
setupNM-Deb8.sh, pi-wifi-setup.sh, and maybe a setting to run a cron job to
monitor the health of the server.

Install Tips for Novice Linux Users Who Want the Easiest Install Method
-----------------------------------------------------------------------
The easiest way to run this (for Linux newbies) is to download and install an
image of Raspbian that already has this script (and a couple other scripts)
installed on it:
https://106.187.53.102/img/NatMsgPi-V001-2016-02-09-raspbian-jessie-lite.img.zip
Remember that you have to unzip that file before installing it on your micro SD
card.

After downloading the SPECIAL image of Raspbian that has scripts installed on
it, unzip it.  Put your new micro SD card into a USB SD card reader and then
follow the tips to put the image onto your SD card.  For generic tips on how to
get the image onto your SD card, see
https://www.raspberrypi.org/documentation/installation/installing-images/README.md,
but keep in mind that novice users should use the custom Raspbian image that
makes it easy to install Natural Message.

At this point, you should have the image on your Raspberry PI SD card, if not
read the prior two paragraphs and try again.

If you have that Raspbian/Natural Message image on your Raspberry Pi
SD card, then...

  0) Before starting, you should be prepared to enter a few passwords.  Make them strong
     passwords, not vocabulary words.  You will need passwords for the following:
     the root user ID, the pi user ID, natmsg user ID, the postgres user ID, the 
     PostGRE SQL database, and, at a later date, a password that you enter when you start
     the Natural Message shard server.  The most important password is the root password,
     because you can use that user ID to reset all the other passwords. If you decide to
     add an extra user ID, you would need a password for that too.  Do NOT put the 
     passwords in any data files in any computer.  If you
     do not have an offline password system, then write them on paper (then hackers can
     not get to your passwords because they are not online).

  1) Put the micro-SD card into your Raspberry Pi.
     Plug in a USB Keyboard into a USB port.
     Plug an Ethernet cable into your Pi and put the other end
     into a working DSL modem (or whatever modem that gives you access
     to the internet--avoid using wifi over the air).
     Plug in a HDMI cable into the side of the Pi and put the
     other end into and HDMI TV monitor or computer monitor
     (I have an HDMI to DVI cable and it works with my old
     computer monitor from 2008).

  2) Insert the SD card that already contains the special image
     of Raspbian that contains the Natural Message scripts.
     The card goes upside down, under the Pi on the end opposite
     from the USB ports.  The card slot is spring loaded, so when it is nearly
     inserted, you will feel a little spring tension, then it should
     stick into place.  To Remove the card, press again, feel the
     spring tension, and then the card should pop out. 

  3) Plug the cord for the power supply into your Pi, then plug the
     the power supply for the Raspberry Pi into the wall socket.
     You should see a couple lights on the Pi light up.

  4) log in with user id 'pi' (do not enter the quotes) and password
     'raspberry' (do not enter the quotes).

  5) You should automatically be in the /home/pi directory without
     having to do anything to get there.  Now type this EXACTLY
     as shown (without the leading #).
       chmod 755 ./pisetup.sh
       sudo ./pisetup.sh

  6) Notes during pisetup.sh...

     * When you get to the keyboard setup routine, the first screen
       should detect the type of keyboard you have, then on the next
       screen, use the arrow keys to scroll down to "Other" and press
       ENTER.
       On the next screen I use the arrow keys to select "English (US)"
       then on the next screen I scroll to the top to selenct the regular
       "English (US)" again, but you can select something that matches 
       your language and keyboard.

     * If you must use wifi for the initial setup, then say 'y' to
       the prompt to set up wifi, then look at the output to see
       the name of your wifi router--use the name that you would
       normally see when you connect to it from another device...
       It should be a name comprised of regualar letter and numbers
       to form readable name (as oppsed to hex codes).
    
    * It is OK to rerun pisetup.sh and it is OK to press Ctl-c
      while pisetup.sh is running if you want to quit.  If you are
      rerunning pisetup.sh, you can say 'n' when asked to run
      parts of the setup that you have already completed.


Manual Install (for Experts only)
---------------------------------
If you know how to use the Linux command line, you can try installing
everything yourself.  The instructions here will be for a Raspberry Pi.

1) You will need a Raspberry Pi (version 2 or better is preferred), an Ethernet
cable, a keyboard, a computer monitor that either accepts HDMI or has a cable
that converits from HDMI, a micro-SD card that will hold the boot image, a
downloaded copy of the Raspbian operating system (currently version 8).  Do not
try to install regular Debian on your Raspberry Pi.  You might be able to
install everything using the Raspberry Pi as a headless server, but that is not
described here.

2) The default user ID for Rasbian is pi and the password is raspberry.

3) Either buy a preformatted Raspbian SD card, or make one yourself.  To make
your own, see https://www.raspberrypi.org/downloads/.  I use the setup for
Raspbian directly, but maybe the Noobs option is better because it might help
you to configure everything.  I use the image for Raspbian Jessie Lite, which
is a minimal install that runs at the command line (no graphical interface).
More install tips are here:
https://www.raspberrypi.org/documentation/installation/installing-images/README.md.

4) If you used the manual install for the Raspian image, you probably need to
repartition your disk and resize the operating system. You can run this on a
live image, but I do it from may laptop writing to an SD card that holds the
Raspbian image:

```
# Check which devices you have
sudo lsblk -a
# modify the next line to point to your SD card
sudo parted --align optimal /dev/sdXXXXX
(parted) unit MiB
(parted) print
(parted) resizepart 2
# then enter an ending block that is very close to the size of the disk 
# as shown in the print command above.
(parted) q
```

5) Put the micro SD card in your Raspberry Pi.  Note that on version 2 and 3 of
the Raspberry Pi, the SD card goes upside down, under the card, on the end that
is opposite of all the USB ports.

6) Plug the Ethernet cable into the back of your DSL router and power on the
Raspberry Pi.

7) Login with user ID pi and password raspberry.

8) Copy these scripts to your Raspberry Pi.  The best way is to activate your
Internet connection and get them directly from github, but if you have no
choice you could put your SD card into a card reader of another computer, then
mount the main partition from your Raspberry Pi disk and copy the files to it.
As a last resort, boot your Raspberry pi and copy the files from a USB stick.

8) If you have to use wifi, then you have to jump through some hoops to get the
wifi to work (at least that is the case on Raspberry Pi 2).  You can read the
comments near the top of pi-wifi-setup.sh in this github or search the Internet
for tips.  It can be frustrating to get the wifi working.

9) Note that it is possible that your machine will need a firmware update or
regression if you also want to run cryptsetup (from March 2016, search the
Internet for: 'rpi-update 0764e7d78d30658f9bfbf40f8023ab95f952bcad').

Natural Message keys and our SSL Keys
-------------------------------------
Part of the installation process for this program requires some SSL keys and
some Natural Message keys.

The original idea was to use a set of keys that would allow users to verify
that they are talking to legitimate shard servers.  The general theory is to
have a master, offline private key that signs an online server key, and the
online server key can sign any chunk of data that a user sends to it during the
server verification process.  We originally created a key system using
libgcrypt (which is used by GNU Privacy Gard [GPG]) and used self-signed SSL
certificates on servers, but Apple made a change in 2015 that made the
self-signed certificates more problematic, so we now have a custom set of SSL
certificates in addition to our libgcrypt certificates.

The first system that we created uses the libgcrypt certificates.  There is an
offline master key pair, the private key is never stored on any computer that
has ever been connected to a network.  The public key associated with that
offline key is distributed so that users can verify that anything signed with
that key is blessed by Natural Message. The offline key lasts forever, but
there is also an online master key that will sign each server key.  The user
application will confirm that the Natural Message (libgcrypt) certificate from
a server was singd by the Natural Message online key, then confirm that the
online key was signed by the offline master key, and also check some expiration
dates.  

Natural Message will have an online SSL certificate authority certificate that
will sign each SSL certificate used by shard servers (this is related to the
need to make Apple's development stack happy with self-signed server SSL
certificates).  The user's app will contain an Online Master SSL key and use
that to verify the self-signed certificates on shard servers.  Although the
usual method of verifying the Online key would by to sign it with an offline
certificate authority key (using the format of SSL keys), we already have the
libgcrypt system to verify signatures, so the client's app will verify that the
online SSL key is signed by the offline master Natural Message key (the
libgcrypt key).

Update the Configuration File
-----------------------------

After completing the installation process, log into your Raspberry Pi
and check the configuration file (this is a one-time setup).

If you are a novice Linux user and do not know how to use the vi
or vim editors, you should probably use the nano text editor.
You can install the editor like this:

```
sudo apt-get -y install nano
```

Now you can edit the config file:

```
cd /var/natmsg/conf
nano conf/natmsg_shard_prod_00_00_20.conf

```

Now go near the bottom of the file and look for the line that says
DB_PW and change the value "YOUR PASSWORD HERE" to the 
database for the Postgre SQL database.

Edit the two lines to point to your SSL certificate and key. The
Line for server.ssl_certificate points to your .crt file and 
the other line points to your .key file.  Ask Bob to send
you SSL keys.


Check the values for server.socket_host and port number and
set them to your IP and port number.  If you are running a Raspberry
Pi in your house behind your DSL router, you might want to try
entering an IP address of 0.0.0.0, which might tell the computer
to respond to the given port number regardless of what the IP is.
If you have a real computer that has its own IP address that is
directly accessible from the Internet, then enter that IP address
in the config file.

Update the fingerprint for your Natural Message Keys.  You can
ask Bob to give you that value.  To calculate that value yourself, 
you can run something like this:

```
openssl dgst -sha384 \
    MyOfflinePUBSignKey.key |tr "[[:lower:]]" "[[:upper:]]"
```

Update the paths for the four ONLINE keys, starting with
ONLINE_PUB_SIGN_KEY_FNAME and including the last one that
called OFFLINE_PUB_SIGN_KEY_FNAME.  For the earliest round of
testing, you can ask Bob to create these files.  If you are an
expert, you can read the notes at the top of the config
file and generate your own keys and then ask Bob to sign your
keys.

Check the maximum shard size.  For small shard servers, perhaps
set the shard size to 256 and the body size a bit bigger.

```
server.max_request_body_size=300
server.max_request_header_size=2000
MAX_SHARD_SIZE_BYTES=256
```

Check the numeric user IDs.  These are needed because
you might need to start the command as root (if you want
to attach to port 443) and then drop to your regular
user ID to minimize the risk of having an unnecessarily
high privilege level.  To check the value, try
running this command in the Pi:

```
ls -ln /home/pi
```

Look in the third and fourth column for numeric values... probably
around 1000 or so.  Those are your numeric user ID and group ID.

Save the config file and exit nano.

Running the Natural Message Shard Server
----------------------------------------

```
cd /var/natmsg/
ls natural*.py
# find the newest shard server program (highest number)
sudo python3 naturalmsg_shardsvr_00_00_24.py  conf=/var/natmsg/conf/shard05.conf
```

