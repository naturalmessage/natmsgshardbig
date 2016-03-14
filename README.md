Overview
--------
This is the "big" Natural Message shard server that saves shards to disk as opposed to in a database.  The idea is to allow people to run their own servers to protect their own messages, the messages of their friends, or the messages of the general public.

These servers can be configured to hold "password shards" (which are tiny files that hold one part of a larger encryption key) or "big shards" (which might hold 1-5 MB pieces of files (the pieces of files are called "shards").  The shard servers hold chunks of information for messages that are sent via Natural Message, and the general idea is for the end-user's app to encrypt the files, split the encrypted file and the (double encrypted) encryption keys into pieces, distribute those pieces across many servers, prevent the central "directory server" from ever having keys to read any files, and allow the recipient to collect all those "burn on read" pieces to reconstruct the message.  All of the shards are burn on read, meaning that after somebody reads the shard, the server destroys all copies of it.

This is not quite ready, but if you want to run a shard server, contact
naturalmessage@fastmail.nl for free help.

Installing
----------
The preferred way to run a shard server is for people to run a "password shard server" on a Raspberry Pi (that means install this program and set an option in the configuration file so that it will accept only tiny files (such as under 300 bytes).  By running a password server, it is very unlikely that the Raspberry Pi will ever hold any actual content that is objectionable.

The best way to run you Raspberry Pi is to make it a dedicated server without adding any other software or using it for any purpose other than a shard server.

If you are not familiar with running a Linux machine from the command line, there will soon be an install image that will make it easier to run your own shard server.  The Raspberry Pi install image will contain pisetup.sh, setupNM-Deb8.sh, pi-wifi-setup.sh, and maybe a setting to run a cron job to monitor the health of the server.

Manual Install
--------------
If you know how to use the Linux command line, you can try installing everything yourself.  The instructions here will be for a Raspberry Pi.

1) You will need a Raspberry Pi (version 2 or better is preferred), an Ethernet cable, a keyboard, a computer monitor that either accepts HDMI or has a cable that converits from HDMI, a micro-SD card that will hold the boot image, a downloaded copy of the Raspbian operating system (currently version 8).  Do not try to install regular Debian on your Raspberry Pi.  You might be able to install everything using the Raspberry Pi as a headless server, but that is not described here.

2) The default user ID for Rasbian is pi and the password is raspberry.

3) Either buy a preformatted Raspbian SD card, or make one yourself.  To make your own, see https://www.raspberrypi.org/downloads/.  I use the setup for Raspbian directly, but maybe the Noobs option is better because it might help you to configure everything.  I use the image for Raspbian Jessie Lite, which is a minimal install that runs at the command line (no graphical interface).  More install tips are here: https://www.raspberrypi.org/documentation/installation/installing-images/README.md.

4) If you used the manual install for the Raspian image, you probably need to repartition your disk and resize the operating system. You can run this on a live image, but I do it from may laptop writing to an SD card that holds the Raspbian image:

```# Check which devices you have
sudo lsblk -a
# modify the next line to point to your SD card
sudo parted --align /dev/sdXXXXX
(parted) unit MiB
(parted) print
(parted) resizepart 2
# then enter an ending block that is very close to the size of the disk 
# as shown in the print command above.
(parted) q
```

5) Put the micro SD card in your Raspberry Pi.  Note that on version 2 and 3 of the Raspberry Pi, the SD card goes upside down, under the card, on the end that is opposite of all the USB ports.

6) Plug the Ethernet cable into the back of your DSL router and power on the Raspberry Pi.

7) Login with user ID pi and password raspberry.

8) Copy these scripts to your Raspberry Pi.  The best way is to activate your Internet connection and get them directly from github, but if you have no choice you could put your SD card into a card reader of another computer, then mount the main partition from your Raspberry Pi disk and copy the files to it.  As a last resort, boot your Raspberry pi and copy the files from a USB stick.

8) If you have to use wifi, then you have to jump through some hoops to get the wifi to work (at least that is the case on Raspberry Pi 2).  You can read the comments near the top of pi-wifi-setup.sh in this github or search the Internet for tips.  It can be frustrating to get the wifi working.

9) Note that it is possible that your machine will need a firmware update or regression if you also want to run cryptsetup (from March 2016, search for 'rpi-update 0764e7d78d30658f9bfbf40f8023ab95f952bcad').

Natural Message keys and our SSL Keys
-------------------------------------
Part of the installation process for this program requires some SSL keys and some Natural Message keys.

The original idea was to use a set of keys that would allow users to verify that they are talking to legitimate shard servers.  The general theory is to have a master, offline private key that signs an online server key, and the online server key can sign any chunk of data that a user sends to it during the server verification process.  We originally created a key system using libgcrypt (which is used by GNU Privacy Gard [GPG]) and used self-signed SSL certificates on servers, but Apple made a change in 2015 that made the self-signed certificates more problematic, so we now have a custom set of SSL certificates in addition to our libgcrypt certificates.

The first system that we created uses the libgcrypt certificates.  There is an offline master key pair, the private key is never stored on any computer that has ever been connected to a network.  The public key associated with that offline key is distributed so that users can verify that anything signed with that key is blessed by Natural Message. The offline key lasts forever, but there is also an online master key that will sign each server key.  The user application will confirm that the Natural Message (libgcrypt) certificate from a server was singd by the Natural Message online key, then confirm that the online key was signed by the offline master key, and also check some expiration dates.  

Natural Message will have an online SSL certificate authority certificate that will sign each SSL certificate used by shard servers (this is related to the need to make Apple's development stack happy with self-signed server SSL certificates).  The user's app will contain an Online Master SSL key and use that to verify the self-signed certificates on shard servers.  Although the usual method of verifying the Online key would by to sign it with an offline certificate authority key (using the format of SSL keys), we already have the libgcrypt system to verify signatures, so the client's app will verify that the online SSL key is signed by the offline master Natural Message key (the libgcrypt key).


