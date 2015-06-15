#!/bin/bash
# Note, for FreeBSD, you probably have to install bash,
# then point to /usr/local/bin/bash above.
#
# natmsg_functions.sh
# copyright 2015 Natural Message LLC.
# author: Robert Hoot
# license: GPLV3

#
###############################################################################
# Copyright 2015 Natural Message, LLC.
# Author: Robert Hoot (naturalmessage@fastmail.fm)
#
# This file is part of the Natural Message Shard Server.
#
# The Natural Message Shard Server is free software: you can redistribute
# it and/or modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.
#
# Natural Message Shard Server is distributed in the hope that it will
# be useful, but WITHOUT ANY WARRANTY; without even the implied
# warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Natural Message Shard Server.  If not,
# see <http://www.gnu.org/licenses/>.
###############################################################################
#
# This is a collection of miscellaneous functions
# for scripts: menus, getting information, whatever
# else I need to do. Most of the functions here came from 
# another project: GNU Secure Home Computing, by Robert Hoot,
# hence the "gshc" prefix everywhere.
# Everything here is GPLV3
#
###############################################################################
# vim notes:
# 1) to correct syntax highlighting problems that
#    change when you scroll or use Ctl-L, try this:
#       let sh_minlines = 500
# 2) to tweak the color display of syntax 'commments' 
#    (if your background color makes other colors look bad)
#         :highlight comment ctermfg=darkgreen guifg=darkgreen
#    then try it for the other syntax categories: Statement Error String
#    Identifer Function Delimiter Operator Special Search IncSearch
#    LineNr Title WildMenu 
#    (note that quotes in shell scripts are colored based on the
#     settings for 'Operator')
# 3) look in /usr/share/vim/vim74/syntax/sh.vim and vim.vim for
#    details.  The vim.vim file should contain a full list of
#    color names--also see /usr/share/vim/vim74/syntax/colortest.vim
# 4) for custom syntax highlighting:
#    *  create a directory called ~/.vim/after/syntax/sh.vim
#    *  add a line to change a color, such as this:
#         highlight comment ctermfg=darkgreen guifg=darkgreen
#    * now when you load a .sh file, comments will be darkgreen
#      (based on the definition of 'darkgreen' according to yoru pallette).
#
# $? expands to the previous return code/prior return code
#      
###############################################################################

# temp notes:
#echo "make temp files like this: 'rsctmp=$(mktemp /tmp/gshc_XXXXXX);'"
#   
#------------------------------------------------------------------------------
#
#  Part I: Essentials for GSHC scripts
#
#------------------------------------------------------------------------------
# vim command to find function names:
#      /^[gshc][[:print:]]*
#
# to find a function that contains the letters "select"
#      /^[gshc][[:print:]]*select
#
# find an 'if' statement that doesn not have 'then' at the end:
#   ^[\t]*if[[:print:]]*[;]$
#



#######################################################################
## MESSAGE BLOCK START -- DO NOT CHANGE THIS LINE ##
# Message variable prefixes:
# WARN=warning; 
# MENU=the text of a menu
# MSG=regular message, or prompt, 
# ERR=error message
# DMSG=debug message



MSG_FAILED="failed"
MSG_QUITTING_NOW="Quitting now."
ERR_ERROR="ERROR."
ERR_CAN_NOT_READ_FILE="ERROR. Can not read file "
MSG_PRESS_KEY="Press any key to continue (or Ctl-c to quit)..."

M=("ERROR. You must be root to run this script." 
     "Try running the command prefixed with 'sudo ' (without the quotes).")
ERR_MUST_BE_ROOT="${M[*]}"

ERR_MUST_BE_DOM0="ERROR. This script can run only on a dom0 host."

ERR_NO_READ_ACCESS="ERROR. No read access to file: "

ERR_INVALID_IFACE_SEL="ERROR. User did not select a valid interface name."

M=("ERROR. The GSHC_PGM_PATH option is missing in ${HOME}/.gshc/gshc.conf."
   "Add a line like this (and point to wherever the GSHC programs are):"
   "GSHC_PGM_PATH=/usr/local/bin"    )
ERR_PATH_OPT_MISSING="${M[*]}"

ERROR_CAN_NOT_READ_DIR="ERROR. Can not read the path for GSHC programs: "

M=("ERROR. the WAN variable is not defined in ${HOME}/.gshc/gshc.conf"
   "This is the device that allows you to access the Internet."
   "Check if all your network devices are connected and"
   "operational, or maybe add an entry in ${HOME}/.gshc/gshc.conf that looks"
   "something like this:"
   "WAN=ens3"
   "(or whatever your device name is instead of ense3)")
ERR_MISSING_WAN_SETTING="${M[*]}"

M=("ERROR. The WAN interface was specified on your option file"
   "but it was not found:."
   "Perhpas modify ${HOME}/.gshc/gshc.conf with a good interface name."
   "Or check if all your network devices are connected and"
   "operational."
   "The WAN setting points to the device that can access the"
   "Internet.")

ERR_BAD_WAN_SETTING="${M[*]}"

ERR_VAR_NOT_DEFINED="ERROR. Variable is not defined in ${HOME}/.gshc/gshc.conf but is needed: "

M=("One or more bad option in ${HOME}/.gshc/gshc.conf."
   "The interfaces that are currently available are:")
ERR_BAD_IFACE="${M[*]}"

M=("ERROR. The default WAN device name is invalid."
   "Please select a new network interface name for the Internet.")
ERR_SELECT_NEW_WAN="${M[*]}"

MSG_CONTINUE="Do you want to continue? (y/n): "

M=("The copy of the tarred gshc scripts to the local repo failed."
   "Maybe the repo at ${GSHC_LOCAL_REPO} was not active"
   "or maybe the permissions on the foreign directories "
   "are inconsistent with the permissions or owner of the gshc.tgz file.")
ERR_COPY_TO_REPO="${M[*]}"

M=("The copy of gshc_setup_vm.sh scripts to the local repo failed."
   "Maybe the repo at ${GSHC_LOCAL_REPO} was not active"
   "or maybe the permissions on the foreign directories "
   "are inconsistent with the permissions or owner of the gshc.tgz file.")
ERR_COPY_TO_REPO02="${M[*]}"

ERR_MISSING_FILE_NAME="ERROR. File name is missing."
ERR_MISSING_TEXT_AND_FILE="ERROR. You must pass either --text or --file-name to gshc_select_row.  Sending text might be a bit more secure and might prevent permission errors.  Be sure to put the text in quotes."
ERR_NOT_A_FILE="ERROR. Not a file:"
ERR_PGM_REQUIRED="ERROR. A program is required for this script, but it is not installed: "
##MSG_SCREEN_NAV="q=quit, n=next screen, p=prev screen, c=change column count or enter a number to select an item: "
MSG_SCREEN_NAV="q=quit, n=next, p=prev, ?=help or enter a number to select an item: "

MSG_SCREEN_NAV_HELP_HDR="HELP FOR THE STANDARD GSHC SCREEN NAVIGATION MENU"
MSG_SCREEN_NAV_HELP="`cat<<EOF
q=quit
  this menu.
n=next
  screen of menu options.
p=previous screen
  of menu options.
c=change the number
  of newspaper-style columns used to display the menu.
f=first screen
  of menu options.
l=last screen
  of menu options.
t=toggle truncate
  lines.
NUMBERS=nubers 1 and higher select
  the menu option.
asdf=mor junk lines as a test
asdfasdf
asd alsdfj a;ls jf ;ljas
asdfl jas fkha dkfhu
alsk fhla sdfjh aksgdf
askldjfg asdlkfh asldkfjh aslkdfg asdf
asdfkg kasdjhf laksjgdf iashdf kjgasdf gh.
EOF
`"

MENU_INSTALL01_HDR="Select the programs that you want to install"

WARN_INVALID_NBR="Invalid number.  Try again."
MSG_INVALID_SEL="The user did not select a valid item."
WARN_UNEXPECTED_OPTION="Unexpected option: "
ERR_SNAP_OPTION_REQUIRED="ERROR. You must specify either --with-snapshots or --no-snapshots (gshc_select_lv)."
ERR_BLANK_POOL_NAME="The pool name is blank in gshc_select_libvirt_vol"    
ERR_BLANK_VM_NAME="ERROR.  The VM name is blank."
MSG_CURRENT_DIR="The current directory is:"
MSG_ENTER_FNAME_OR_SELECT="Enter a filename (or ENTER to select): "
MSG_YOU_CHOSE="You chose: "
MSG_PGM_NOT_INSTALLED="WARNING. An important program was not found: "
MSG_INSTALL_NOW="Do you want to install it now? (y/n) "
ERR_PGM_NOT_FOUND="ERROR. Program was not found:"
MSG_SPECIFY_FULL_PATH="Try specifying the full path if you think the program is installed."
ERR_MISSING_UUID_TO_MOUNT="ERROR. The UUID to mount is missing."
ERR_MOUNT_PT_MISSING="ERROR. The mount point is missing."
WARN_ALREADY_MOUNTED="WARNING. The device is already mounted: "
MSG_NEED_NBR_OF_KEYS="You must pass a count of the nunber of keys you want."
MSG_BAD_MOUNT_TO_MOUNT_POINT="Could not mount device to mount point: "
MSG_SUCCESSFUL_MOUNT_TO_MT_PT="Successful mount to mount point: "
MSG_ENCRYPT_PROMPT_01="Do you want to encrypt the file into ASCII format? (y/n) "
MSG_ENTER_A_NUMBER="Enter a number: "
MSG_APPEARS_TO_BE_TEXT="The input file appears to be text."
MSG_ASCII_ARMOR_INPUT="Is the input file an encrypted file in 'ASCII-armor' format? (y/n): "
WARN_OUTPUT_FILE_EXISTS="WARNING: The output file already exists."
MSG_OVERWRITE_RENAME="Press o to Overwrite or r to rename it: "

MSG_ACTION_EQUALS="action = "
MSG_INPUT_FILE_EQUALS="input file = "
MSG_OUTPUT_FILE_EQUALS="output file = "
MSG_COMPRESSION_EQUALS="compression = "
MSG_CONFIRM_SETTINGS="Confirm the settings:"
MSG_IN_ASCII_FORMAT="in ASCII format."
MSG_IN_BINARY_FORMAT="in binary format."

M=("WARNING: ${HOME}/.gshc/gshc.conf does not have an entry for network"
   "time sync source.   Setting GSHC_NTP_URL='1.us.pool.ntp.org'")
MSG_TIME_SYNC_MISSING="${M[*]}"

M=("WARNING: ntpdate could not synchronize the computer time with"
   "Internet sources.  Some programs, like TOR, will not work"
   "properly with an inaccurate clock.")
WARN_NTPDATE_FAILED="${M[*]}"

MSG_MISSING_OPT_GET_NBR="You must pass the prompt text and max nbr to gshc_get_nbr_input()"
MSG_MISSING_PROMPT="You must pass the prompt text to this function: "

M=("Enter one or more text strings, then press ENTER"
   "and add more strings.  Leave a blank line to finish.")
MSG_ARRAY_PROMPT="${M[*]}"

MSG_ENTRY_OK="Does that entry look OK? (y/n) "
ERR_NO_UUID="ERROR.  There was no UUID passed to function: "

MSG_DEV_INFO_01="Here is some info about"

M=("that was extracted from the udisks program:"
     "(the format of this report will change in the future)")
MSG_DEV_INFO_02="${M[*]}"

ERR_MISSING_OPTION="ERROR.  Missing option for: "
MSG_FUNCTION_EQUALS="function ="
ERR_DEVICE_NOT_FOUND="ERROR. Device not found: "
ERR_EXISTING_MOUNT="ERROR Something unexpected is already mounted at the mount point: "
#"

MSG_ENTROPY_01=$(cat<<EOF
You will be prompted to enter $E_COUNT strings that will be used to
add entropy to the system random number generator (or at least disrupt
any prediction of encryption keys). Each time you are prompted, you
should enter at least 10 characters (30 is better). You can type
randomly or use a judiciously random process like coin flipping.
EOF
)

    
MSG_ENTROPY_02=$(cat<<EOF
If you want to type randomly, press ENTER now to continue, otherwise
keep reading...  If you want to use the coinflip method, put either 20
coins or maybe 128 coins in a can (or lots of coins), shake the can,
then dump them on the table and order them in a single line.  Then
type 'h' for heads and 't' for tails (the actual letter does not
matter as long as you have a consistent method). Repeat for each key.
_    
Example entry: thhtthhtht
_    
You could also enter something from the right side of the keyboard for
heads and something from the left side for tails.
EOF
)


MSG_ENTROPY_03=$(cat<<EOF
Enter at least 10 random characters each time you are prompted.
The results will be used to add encryption entropy to the system.
Typos are fine--extra characters are fine--they add entropy!
EOF
)
    
MSG_ENTROPY_04="Enter at least 10 keystrokes:"

MENU_COMPRESS_FORMAT=$(cat<<EOF
Select a compression format:

1) gzip
   .
2) bzip2 
   (slower but better compression for large files)
3) none
   .
EOF
)

## MESSAGE BLOCK END   -- DO NOT CHANGE THIS LINE ##
###############################################################################

## A confirmation Yes/No function with optional prompt.
gshc_confirm(){
    local tmp_FIN="N"
    local yn=''
    local MY_PROMPT="$1"
    if (test -z "${MY_PROMPT}"); then
        local MY_PROMPT="${MSG_CONTINUE}"
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

gshc_continue(){
    read -p "${MSG_PRESS_KEY}" junk
}

gshc_pause(){
    local junk=""
    echo -n "${MSG_PRESS_KEY}"
    read junk
    return 0
}

gshc_is_root(){
    # Quietly returns 0 if the user is root otherwise nonzero.
    # There might be a need to run different tests based on
    # the OS and what utilities are installed.

    if [ -n "$EUID" ]; then
        # The system defines $EUID, which is the effective user,
        # which would reflect any 'su' or 'sudo' commands, 
        # if they are active.
        if [ "$EUID" = "0" ]; then
            return 0
        else
            # not root
            return 12
        fi    
    else
        # This system does not define $EUID.
        # If the 'id' program is installed, use it:
        if (gshc_is_installed "id"); then
            # the 'id' program is available, so use it
            if [ ! "`id -u`" = "0" ]; then
                # user is not root
                return 12
            fi
        else
            # The 'id' program is not installed, force
            # installation of whoami if it is not already
            # installed.
            if (gshc_installed_check "whoami"); then
                if !(test "`whoami`" = "root"); then
                    # User is not root, return error code.
                    return 12
                fi
            else
                # what to do?  the $USER setting doesn't
                # work under 'sudo' ???
                return 12
            fi
        fi
    fi

    return 0
}

gshc_require_root(){
    # This function will run two tests to see if 
    # the current user has root privileges and post an error
    # message if the user is not root.
    # It is up to the caller to exit on failure if that is
    # desired.

    if !(gshc_is_root); then
            echo "${ERR_MUST_BE_ROOT}"
            sleep 3
            return 12
    fi
    return 0
}
gshc_get_os(){
    # Purpose:
    # 1) Define some global variables to describe the OS.
    #    The output will be used to determine which commands
    #    to run for certain OS or OS-version.
    # 2) This sets two global variables: GSHC_OS
    #    and GSHC_OS_VER

    local silent='F'

    # Parse options
    while [ "$1" != "${1##[-+]}" ]; do
        ###clear
        case $1 in
            '')    gshc_err_print "$0: Usage: gshc_get_os [--silent] " \;
                         return 1;;
            
            --silent)
                silent='T';
                shift
                ;;
    
            *)
                gshc_err_print "ERROR. Unexpected option: $1"
                return 12
                ;;
        esac
    done

    if [ -f /etc/centos-release ]; then
        GSHC_OS="CentOS"
        GSHC_OS_VER="`cat /etc/centos-release|cut -d ' ' -f 3`"    
    elif [ -f /etc/fedora-release ]; then
        GSHC_OS="Fedora"
        GSHC_OS_VER="`cat /etc/fedora-release|cut -d ' ' -f 3`"    
    elif [ -f /etc/os-release ]; then
        sys_stuff=$(uname -a|grep -i debian)
        if [ -n "${sys_stuff}" ]; then
            # The os-release file contains shell variable definitions,
            # so evaluate them with 'eval':
            eval $(cat /etc/os-release)
            GSHC_OS="${NAME}"
            GSHC_OS_VER="${VERSION_ID}"
        else
            GSHC_OS="UNKNOWN"
            GSHC_OS_VER="UNKNOWN"
        fi
    fi

    if !(test "${silent}" = "T"); then
        echo "$GSHC_OS"
    fi

    return 0
}

gshc_get_fedora_release(){
    if (test -r /etc/fedora-release); then
        cat /etc/fedora-release|cut -d ' ' -f 3
    else
        echo "${ERR_CAN_NOT_READ_FILE}"
        echo "/etc/fedora-release."    
        return 12
    fi
    return 0
}

gshc_safe_move(){
    # Move a file only if the user has write access to the source
    # and can create the target. This is not infallible but prevents some situations
    # that can result in a corrupted file or unexpected state 
    # (e.g., duplicate files).
    # This might not reflect access from ACLs.
    from_file="$1"
    to_file="$2"

    if [ -f "${to_file}" ]; then
        echo "Error. the destination file already exists."
        echo "Either delete the destination or pick a unique destination."
        return 95
    fi

    allowed_to_move="FALSE"
    if gshc_is_root; then
        allowed_to_move="TRUE"
    elif [ -O "${from_file}" ]; then
        # File is owned by the user
        allowed_to_move="TRUE"
    elif [ -G "${from_file}" ]; then
        # File is owned by the current group
        allowed_to_move="TRUE"
    elif [ -w "${from_file}" ]; then
        # File is owned by the current group.
        # Not that the system will issue a permission error 
        # if the file is owned by root and group is set
        # to the current group, and the user will still
        # be able to move the file (on Fedora at least).
        allowed_to_move="TRUE"
    fi

    if [ "${allowed_to_move}" = "TRUE" ]; then
        echo "testing write access and free space" > "${to_file}-junk.tmp"
        if [ $? = 0 ];then
            if [ $? = 0 ]; then
                rm "${to_file}-junk.tmp"
                if [ $? = 0 ]; then
                    mv "${from_file}" "${to_file}"
                else
                    echo "I seem to lack delete access, so I will not "
                    echo "try to move the file."
                    return 96
                fi
            else
                echo "Error moving the file"
                return 97
            fi
        else
            echo "Error.  Could not create a test file at the target:"
            echo "${to_flie}"
            return 98
        fi
    else
        if [ -f "${from_file}" ]; then
            echo "Error.  The source file exists but you lack authority to move it safely."
            echo "${from_file}"
            return 88
        else
            echo "Error. Could not access the source file:"
            echo "${from_file}"
            return 89
        fi
    fi
    return 0
}

gshc_date_dec(){
    # Given one argument in the form YYYYJJJHH
    # such as from `date +"%Y%j%H"
    # define a the YYYY_DDDDDD variable in the form YYYY.DDDDDD
    # where the .DDDDDD is the decimal part of the year that has passed.
    # (Extra characters at the end of the argument will be safely ignored if they are numeric
    # with no embedded spaces or characters)
    local YYYYJJJHH=$1
    local DAY=`echo "${YYYYJJJHH}"|cut -b 5-7`
    local YYYY=`echo "${YYYYJJJHH}"|cut -b 1-4`
    local HOUR=`echo "${YYYYJJJHH}"|cut -b 8-9`
    local DAYS_IN_YEAR=`date -d "${YYYY}/12/31" +"%j"`
    YYYY_DDDDDD=`echo "scale=6;${YYYY}+(${DAY}+${HOUR}/24)/(${DAYS_IN_YEAR} + 1)"|bc -l`
    echo "YYYY (decimal) day = ${YYYY_DDDDDD}"

    ###return ${YYYY_DDDDDD}
    return 0
}

gshc_list_fs(){
    # This will list the filesystems (e.g., ext2, ext3...)
    # that the kernal supports.
    # for old fedora/centOS:
    if [ -f /proc/filesystems ]; then
        cat /proc/filesystems |grep -v "^nodev[[:space:]]"
    fi
}

gshc_guess_mount_dir(){
    # Guest operating systems might prefer a particular
    # mount point for mounting newly attached devices
    # such as USB drives.  This will guess what that
    # directory is based on the current operating system
    # and version.
    # This currently has poor logic and would benefit
    # with more precise logic for different OS.

    if (test "`gshc_get_os`" = "Fedora"); then
        echo "/run/media/$USER"
    else
        # Ubuntu, Debian, OpenBSD and others?
        echo "/media"
    fi
}


gshc_is_mounted() {
    # see if the specified device is mounted
    # returns 0 if it is mounted else 1/FALSE
    local DEV="$1"
    if !(test -z "$(mount|grep "^${DEV} ")"); then
        return 0;
    else
        return 1;
    fi
}



gshc_mount_unencrypted_dev(){
    # Given either a UUID or device path, mount it.
    # (designed for CentOS originally, not OpenBSD. OpenBSD has
    # better ability to mount by UUID).
    #
    # It is safest to provide a UUID, but this will take
    # a device path like /dev/sdb2.
    #
    gshc_dprint 6 "mount_unencrypted_dev: top"

    local D_UUID=""
    local MOUNT_PT=""
    local DEV_PATH=""
    local STORAGE_DEV=''
    local MT_PARMS=''
    # the user will pass the full mount options, like "--uid=1009 -F -l -o ro" without the quotes.
    local MOUNT_OPTS=''

    while [ "$1" != "${1##[-+]}" ]; do
        case $1 in
            '')   gshc_err_print "$0: Usage:"
                        gshc_err_print "gshc_mount_unencrypted_dev { --uuid=DEV_UUID, --dev-path=DEV_PATH } "
                        gshc_err_print "--mount-pt=MOUNT_POINT [--mount-opts=OPT1,OPT2,OPT3]"
                        gshc_err_print "where DEV_PATH is something like /dev/sdb2"
                        return 1;;
            
            --uuid=?*)
                local D_UUID=${1#--uuid=}
                shift
                ;;

            --dev-path=?*)
                local DEV_PATH=${1#--dev-path=}
                shift
                ;;

            --mount-pt=?*)
                local MOUNT_PT=${1#--mount-pt=}
                shift
                ;;

            --mount-opts=?*)
                local MOUNT_OPTS=${1#--mount-opts=}
                shift
                ;;


            *)
                gshc_err_print "${WARN_UNEXPECTED_OPTION} $1 (in mount_unencrypted_device)"
                shift
                return 12
                ;;
        esac
    done

    if (test -z "$D_UUID"); then
        if (test -z "$DEV_PATH"); then
            gshc_err_print "${ERR_MISSING_UUID_TO_MOUNT} (mount_unecrypted_dev)."
            return 12
        else
            # DO NOT GET THE DEVICE UUID BECAUSE THE findfs program
            # does not reliably find LVM LVs.
            ### escaped_dev_path=$(gshc_add_escapes "${DEV_PATH}")
            ### D_UUID=$(sudo blkid|grep "^${escaped_dev_path}[:]"|cut -d ' ' -f 2|cut -d '"' -f 2)
            STORAGE_DEV=${DEV_PATH}
        fi
    fi

    if (test -z "$MOUNT_PT"); then
        gshc_err_print "${ERR_MOUNT_PT_MISSING} (mount_unecrypted_dev)."
        return 12
    fi

    if !(test -d "MOUNT_PT"); then
        if !(mkdir -p "$MOUNT_PT"); then
            echo "ERROR. Failed to create mount point: ${MOUNT_PT}"
            return 12
        fi
    fi

    #
    if (test -z "${STORAGE_DEV}"); then
        # If the user did not supply the input device
        # find it using the UUID:
        STORAGE_DEV="`gshc_findfs "$D_UUID"`"
    fi

    gshc_dprint 1 "mount_unencrypted_dev: mount unencrypted, D_UUID=${D_UUID}"
    gshc_dprint 1 "mount_unencrypted_dev: mount unencrypted, DEV_PATH=${DEV_PATH}"
    gshc_dprint 1 "mount_unencrypted_dev: mount unencrypted, STORAGE_DEV=${STORAGE_DEV}"
    gshc_dprint 1 "mount_unencrypted_dev: mount unencrypted, mt pt=${MOUNT_PT}"
    gshc_dprint 1 "mount_unencrypted_dev: mount unencrypted, mt opts=${MOUNT_OPTS}"



    if (gshc_is_mounted "$STORAGE_DEV"); then
        gshc_err_print "${WARN_ALREADY_MOUNTED} ${STORAGE_DEV}"
        # TO DO: ADD A CHECK TO SEE IF THE CORRECT THING IS MOUNTED
        escaped_dev=$(gshc_add_escapes "${STORAGE_DEV}")
        mount |grep "^${escaped_dev} "
    else
        ###if (test "$RO_FLAG" = '-ro'); then
        if !(test -z "${MOUNT_OPTS}"); then
            MT_PARMS="-o ${MOUNT_OPTS}"
        fi

        gshc_dprint 1 "mount_unencrypted_dev: Mounting $D_UUID ${STORAGE_DEV} to $MOUNT_PT with options ${MOUNT_OPTS}"
        # WARNING, DO NOT PUT QUOTES AROUND mt_parms,
        # it might be intentionally empty and I don't want to mess up
        # the call to mount.
        if (mount  ${MT_PARMS} "$STORAGE_DEV" "$MOUNT_PT"); then
            gshc_err_print "${MSG_SUCCESSFUL_MOUNT_TO_MT_PT} $MOUNT_PT"
        else
            gshc_err_print -n "${ERR_ERROR} $0."
            gshc_err_print -n "${MSG_BAD_MOUNT_TO_MOUNT_POINT}"
            gshc_err_print "$STORAGE_DEV --> $MOUNT_PT"
            return 12
        fi
    fi
}


gshc_rm(){
    # Test if a file exists and delete if if so.
    # (conditional delete)
    local my_file="$1"
    if (test -e "${my_file}"); then
        gshc_dprint 3 "gshc_rm will delete: ${my_file}."
        rm "${my_file}"
    fi
}

### NOT FOR NATMSG:
## gshc_show_opts(){
##     # the next block will read the option file; exclude comment lines;
##     # keep only those lines that look like a variable name followed by "=";
##     # an parse out the variable name, which goes into $j.
##     for j in $(grep -v "^[ ]*[#]" ${HOME}/.gshc/gshc.conf|grep  "^[[:graph:]]*\="|tr -s '\n\n'|cut -d '=' -f 1); do
##         env|grep "^${j}="
##     done;
## 
## }
gshc_is_installed(){
    # If the pgm is installed, return success (0) 
    # else return failure.

    #### first check if the "whereis" program exists in the usual places
    ### if !(test -x /usr/bin/whereis); then
    ###     if !(test -x /usr/sbin/whereis); then
    ###         if (test -z "`whereis -b "whereis"|cut -d ":" -f 2`"); then
    ###             ## Note that the whereis program seems to always
    ###             ## return zero, so check its output rather than return code.
    ###             gshc_err_print "${MSG_PGM_NOT_INSTALLED} 'whereis'"
    ###             if (gshc_confirm "${MSG_INSTALL_NOW}"); then
    ###                 if !(yum -y install "whereis"); then
    ###                     # installation failed
    ###                     return 32
    ###                 fi
    ###             fi
    ###         fi
    ###     fi
    ### fi

    local PGM="$1"

    ##if (test -z "`whereis -b "$1"|cut -d ":" -f 2`"); then
    if (test -z "`type -p "$1"`"); then
        # the program was not found
        gshc_err_print "${ERR_PGM_NOT_FOUND}"
        return 12
    fi

    return 0
}

gshc_installed_check_run_bg(){
    # The user passes a program name, and this function
    # checks if it is installed and prompts the user
    # to install it if it is not found in the default
    # search paths, then runs it IN THE BACKGROUND!!!
    # BE SURE TO TERMINATE THIS WITH A SEMICOLON TO AVOID
    # INTERPRETING SUBSEQUENT THINGS AS OPTIONS
    local PGM="$1"
    ###if (test -z "`whereis -b "${PGM}"|sed -e 's/$1[:]//'`"); then
    if (test -z "`type -p "$1"`"); then
        gshc_err_print "${MSG_PGM_NOT_INSTALLED} '$PGM'"
        if (gshc_confirm "${MSG_INSTALL_NOW}"); then
            if !(yum -y install "$PGM"); then
                # installation failed
                return 32
            fi
        fi
    fi
    # If the program exists now, run it
    ###if !(test -z "`whereis -b "${PGM}"|sed -e 's/$1[:]//'`"); then
    if !(test -z "`type -p "$1"`"); then
        gshc_dprint 1 "Attempting to run the requested program"
        "$1" $2 ${3} ${4}&
    else
        gshc_err_print "${ERR_PGM_NOT_FOUND} '$1'"
        gshc_err_print "${MSG_SPECIFY_FULL_PATH}"
        gshc_pause
        return 12
    fi
    
    # The return code is a bit fuzzy here.
    # A 0 means that I got as far as requesting the
    # program to run in the background asyncronously.
    return 0
}

gshc_installed_check(){
    # The user passes a program name, and this function
    # checks if it is installed and prompts the user
    # to install it if it is not found in the default
    # search paths.
    # If you want a boolean aanswer, run gshc_is_installed (which
    # is in gshc main script).

    # TO DO: DECIDE IF THIS SHOULD FAIL IF THE PROGRAM IS NOT AVAILABLE.


    # NOTE: I originally used the 'whereis' command, but
    # the 'type -p' command is a bash internal command
    # that essentially shows where the program is
    # without me having to require the user to install the 'whereis'
    # program.
    # One of my functions, maybe  'installed_check', 
    # can be a pain if the user is running yum in another window.

    ##if !(test -x /usr/bin/whereis); then
    ##    if !(test -x /usr/sbin/whereis); then
    ##        if !(test "`whereis -b "$1"|cut -d ":" -f 1`" = "whereis"); then
    ##            gshc_err_print "${MSG_PGM_NOT_INSTALLED} 'whereis'"
    ##            if (gshc_confirm "${MSG_INSTALL_NOW}"); then
    ##                if !(yum -y install whereis); then
    ##                    # installation failed
    ##                    return 32
    ##                fi
    ##            fi
    ##        fi
    ##    fi
    ##fi

    local PGM="$1"
    ##if (test -z "`whereis -b "$1"|sed -e "s/$1[:]//"`"); then
    if (test -z "`type -p "$1"`"); then
        gshc_err_print "${MSG_PGM_NOT_INSTALLED} '$1'"
        if (gshc_confirm "${MSG_INSTALL_NOW}"); then
            # Allow the user to confirm after seeing the
            # estimated download size, then install:
            if !(yum install "$1"); then
                # installation failed
                return 32
            fi
        fi
    fi
    return 0
}

gshc_installed_check_run(){
    # The user passes a program name, and this function
    # checks if it is installed and prompts the user
    # to install it if it is not found in the default
    # search paths, then runs it AND WAITS FOR IT TO FINISH.
    # BE SURE TO TERMINATE THIS WITH A SEMICOLON TO AVOID
    # INTERPRETING SUBSEQUENT THINGS AS OPTIONS
    local PGM="$1"
    if !(gshc_installed_check "$PGM"); then
        # The program was not found and not installed, 
        # return an error
        return 12
    fi
    # if the program exists now, run it
    # with up to three arguments:
    # echo "running the following command with option arguments: $PGM $2 $3 $4"
    if !("$PGM" $2 $3 $4); then
        # execution of the program with its arguments failed
        return 12
    fi
    return 0
}

# zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz

# ------------------------------------------------------------------------------
#                       Input Routines
#
#
gshc_get_nbr_input(){
    # Prompts user to enter an integer between 1 and 
    # the value of the second argument.
    # The return value is saved in the global variable: $G_NBR.
    # The user should provide two arguments: text for a prompt and 
    # a maximum nbr that would be accepted as valid.
    # If the user enters "q" to quit, $G_NBR will be set to zero.
    # 

    if (test -z "$2"); then
        echo "${ERR_ERROR}. $0. ${MSG_MISSING_OPT_GET_NBR}"
        gshc_pause;
        return 0
    fi
    # The return value is put into $G_NBR    
    G_NBR=0
    local MY_PROMPT="$1"
    local tmp_max=$2

    if (test -z "$MY_PROMPT"); then
        # Define the default prompt text.
        MY_PROMPT="Enter a number (or Q to quit)"
    fi

    while ( test ${G_NBR} -lt 1 || test ${G_NBR} -gt ${tmp_max} ); do
        G_NBR=''
        read -p "$MY_PROMPT" G_NBR
        if (test -z "$G_NBR" ); then
            # Put a negative number into G_NBR to perpetuate
            # the prompt loop.
            G_NBR=-1
        else
            # delete letters and space
            if (test "$G_NBR" = "q" || test "$G_NBR" = 'Q'); then
                    G_NBR=0
                    return 0    
            fi
            # Remove non-numeric characters
            # (invalid characters or blank will be set to 0):
            G_NBR=`gshc_make_numeric "$G_NBR"`

            if (test $G_NBR -eq 0 || test -z "$G_NBR"); then
                # Put a negative number into G_NBR to perpetuate
                # the prompt loop.
                G_NBR=-1
            fi
        fi
    done;

    return 0
}

gshc_get_txt_input(){
    # Prompts user to enter text, 
    # and puts the value in a global variable called
    # G_TXT.
    # THIS NO LONGER PROMPTS FOR CONFIRMATION.

    if (test -z "$1"); then
        echo "${MSG_MISSING_PROMPT} gshc_get_txt_input" 
        return 12
    fi
    # The return value is put into $G_NBR    
    G_TXT=""
    local MY_PROMPT="$1"

    ##while ( true); do
        read -p "$MY_PROMPT" G_TXT
    ##    echo "You entered: $G_TXT"
    ##    if (gshc_confirm "Do you want to keep this answer? (y/n) "); then
    ##        break
    ##    fi
    ##    G_TXT=""
    ##done;

    return 0
}

gshc_get_txt_input_confirm(){
    # Prompts user to enter text, 
    # and puts the value in a global variable called
    # G_TXT.

    if (test -z "$1"); then
        echo "${MSG_MISSING_PROMPT} gshc_get_txt_input" 
        return 12
    fi
    # The return value is put into $G_NBR    
    G_TXT=""
    local MY_PROMPT="$1"

    while ( true); do
        read -p "$MY_PROMPT" G_TXT
        echo "You entered: $G_TXT"
        if (gshc_confirm "Do you want to keep this answer? (y/n) "); then
            break
        fi
        G_TXT=""
    done;

    return 0
}


gshc_get_array_input(){
    # Prompts user to enter multiple records of text,
    # with optional confirmation at the end. 
    # and puts the value in a global variable called
    # GSHC_ARRAY_TMP

    local MY_PROMPT="$1"
    if (test -z "$1"); then
        echo "${MSG_MISSING_PROMPT} gshc_get_txt_input()"
        return 12
    fi

    # The return value is put into $GSHC_ARRAY_TMP
    if (test -z "${GSHC-ARRAY_TMP}"); then
        declare -a GSHC_ARRAY_TMP    
    else
        unset GSHC_ARRAY_TMP[*]
    fi


    local tmp_txt
    echo " "
    echo " "
    echo "${MSG_ARRAY_PROMPT}"
    j=0
    while (true); do
        read -p "$MY_PROMPT" tmp_txt
        if !(test -z "$tmp_txt"); then
            GSHC_ARRAY_TMP[$j]="$tmp_txt"
            j=$(( $j + 1 ))
        else
            # end the input loop
            break
        fi
    done;

    # display and confirm entry:
    j=0
    while (test $j -lt ${#GSHC_ARRAY_TMP[*]}); do
        # Display what the user entered and add line numbers
        printf "%04d  %s\n" $j "${GSHC_ARRAY_TMP[$j]}";
        j=$(( $j + 1 ))
    done

    if !(test -z "${GSHC_ARRAY_TMP[*]}"); then
        # confirm entry only if something was entered.
        while (true); do
            if !(gshc_confirm "${MSG_ENTRY_OK}" ); then
                # Allow the user to correct entries.
                # Note: get_nbr_nput sets global value for ${G_NBR}
                # TO DO : ADD AN OPTION TO ADD ADDTIONAL RECORDS.
                # TO DO : ADD AN OPTION TO ADD ADDTIONAL RECORDS.
                # TO DO : ADD AN OPTION TO ADD ADDTIONAL RECORDS.
                # TO DO : ADD AN OPTION TO ADD ADDTIONAL RECORDS.
                gshc_get_nbr_input "Enter the number of the entry to change" ${#GSHC_ARRAY_TMP[*]}
                read -p "Enter the replacement string for number ${G_NBR}: " tmp_text
                GSHC_ARRAY_TMP[$(( ${G_NBR} - 1 ))]="$tmp_text"
            else
                # Exit the text-correction loop.
                break
            fi
        done
    fi

    return 0
}
# ------------------------------------------------------------------------------
#                     Output Routines
#

gshc_display_errmsg(){
    echo "CHANGE THE SCRIPT TO USE gshc_display_err"
    gshc_display_err $*
}

gshc_display_err(){
    # This is like gshc_display_msg, except the output
    # goes to stderr.
    # A "msg" here is a collection of text with possible
    # paragraph separators that will be processed with
    # the 'fmt' program so that neat, word-wrapped
    # messages will be displayed on the screen regardless
    # of the screen width.
    #
    # 
    local msg_txt="$1"
    # Some screen-size settings
    ##s_rows=`stty size|cut -d ' ' -f 1`
    s_cols=`stty size|cut -d ' ' -f 2`
    if [ -f /etc/freebsd-update.conf ]  || [ -f /bsd ]; then
        # freebsd version
        echo -e "${msg_txt}"|fmt  -w $s_cols > /dev/stderr
    else
        echo -e "${msg_txt}"|fmt -c --width=$s_cols > /dev/stderr
    fi
}

gshc_line_count(){
    # echo the count of the number of lines in the specified file
    # Example usage:
    #
    #        mylinecount=`gshc_line_count /tmp/gshc_setup_vm.sh`
    #        echo "mylinecount is $mylinecount"
    #        if (test -z "${mylinecount}"); then
    #            gshc_err_print "ERROR. line count is missing. the file is probably not readable."
    #            return 12
    #        fi
    #        if (test ${mylinecount} -eq 1324); then
     #         echo "the line count is 1324"
    #        fi

    fname="$1"
    if !(test -f "${fname}"); then
        gshc_display_err "${ERR_NOT_A_FILE} (in gshc_line_count)."
        return 12
    fi
    wc -l "$1" |cut -d ' ' -f 1
    return 0
}


#aaaaaaaa
gshc_err_print(){
    # This prints error messages to stderr
    # and optionally pauses if the GSHC_PAUSE_ON_ERROR
    # option is set and is nonzero.
    # See also: gshc_display_errmsg, which formats 
    # the error message

    # The shift command dumpts the $0 argument and
    # thereby leaves only real arguments in $*
    echo $* > /dev/stderr
    if !(test -z ${GSHC_PAUSE_ON_ERROR}); then
        sleep ${GSHC_PAUSE_ON_ERROR}
    fi
}

gshc_dprint(){
    # Conditionally print a message to stderr
    # if the level in the option here is <= the
    # the global setting, and the global setting
    # is greater than 0 

    if (test -z "$GSHC_DEBUG_LVL"); then
        GSHC_DEBUG_LVL=0
    fi

    if (test "$GSHC_DEBUG_LVL" = "0"); then
        return 0
    fi

    local lvl="$1"
    shift

    if (test $lvl -le $GSHC_DEBUG_LVL); then
        echo "DEBUG: $*" > /dev/stderr
    fi

}

#
gshc_display_msg(){
    # A "msg" here is a collection of text with possible
    # paragraph separators that will be processed with
    # the 'fmt' program so that neat, word-wrapped
    # messages will be displayed on the screen regardless
    # of the screen width.
    #
    # The optional second argument is the number of characters
    # for the desired width of the display (e.g., 80).
    # 
    local msg_txt="$1"
    local screen_cols=$2
    # Some screen-size settings
    ##s_rows=`stty size|cut -d ' ' -f 1`
    if(test -z "${screen_cols}"); then
        screen_cols=`stty size|cut -d ' ' -f 2`
    fi    

    if [ -f /etc/freebsd-update.conf ]  || [ -f /bsd ]; then
        # freebsd version        
        echo -e "${msg_txt}"|fmt  -w $screen_cols
    else
        # linux
        echo -e "${msg_txt}"|fmt -c --width=$screen_cols
    fi
}


gshc_select_menu_entry(){
    # This will display the text of the menu using
    # the gshc_display_msg function (whch uses the
    # 'fmt' program) and then prompt the user
    # to enter a number from 1 to the maximum
    # legal value.  
    #
    # This calls gshc_select_line, which will set
    # the global variable G_NBR to the entered value.
    # The caller must create the entire menu and
    # test the display using gshc_display_msg.
    # 
    local menu_body_txt="$1"
    local menu_hdr_txt="$2"
    local max_entry_nbr="$3"
    if (test -z "$max_nbr"); then
        max_entry_nbr=99
    fi

    if (test -z "${menu_hdr_txt}");then
        gshc_err_print "ERROR. Menu header text is missing for body text: $menu_body_txt"
        return 12
    fi
    local tmp_fname1="`mktemp /tmp/gshc_sme_XXXX`"
    echo "${menu_body_txt}" > "${tmp_fname1}"

    gshc_dprint 3 "QQQQ in gshc_select_menu_entry BEFORE calling select_line"
    gshc_select_line --file-name="${tmp_fname1}" \
      --header="${menu_hdr_txt}" \
        --no-line-nbrs --format-body-text --no-truncate --col-count=1

    gshc_dprint 3 "QQQQ in gshc_select_menu_entry after calling select_line"

    return 0
}
#------------------------------------------------------------
#------------------------------------------------------------
#------------------------------------------------------------
#------------------------------------------------------------
#------------------------------------------------------------

gshc_select_row(){
# THIS IS BEING DEPRICATED - USE GSHC_SELECT_LINE INSTEAD
    # Given a filename, show a list of the rows in that file
    # (assumed to be text).  By default, this function will
    # add line numbers to each input row,
    # and prompt the user to select one by entering a number.
    # This will set the global variable G_NBR with the selected row nbr.
    # or zero if the user did not select anything.
    # The user can scroll to the next an previous screen, or 
    # first or last screen if the data is too big to fit on one screen.
    # The user can adjust options for the number of newspaper-style
    # columns displayed and line-truncation.
    #
    # TO DO: allow the caller to specify context-sensitive
    # help text and an override prompt text.

    local screen_idx=1
    local truncate='T' # default is True
    local add_line_nbrs='T' # default is True
    local format_body_text='F' #call gshc_display_msg for the body of the menu
    local col_count=2 # default number of newspaper-style columns
    local tmp_fname1="`mktemp /tmp/gshc_sra_XXXX`"
    local tmp_fname2="`mktemp /tmp/gshc_srb_XXXX`"



    while [ "$1" != "${1##[-+]}" ]; do
        ###clear
        gshc_dprint 1 "top of gshc_select_row ARG loop for option $1"
        case $1 in
            '')   gshc_err_print "$0: Usage: gshc_select_row --file-name=FNAME " \;
                        gshc_err_print "--header='HEADER/TITLE' [--col_count=2] [{--truncate, --no-truncate}]"
                        gshc_err_print "where 'col-count' is the number of newspaper-style"
                        gshc_err_print "columns displayed."
                         return 1;;
            
            --truncate)
                truncate='T';
                shift
                ;;

            --no-truncate)
                truncate='F';
                shift
                ;;

            --no-line-nbrs)
                add_line_nbrs='F';
                shift
                ;;

            --format-body-text)
                format_body_text='T';
                shift
                ;;

            --file-name=?*)
                local input_fname=${1#--file-name=}
                shift
                ;;

            --header=?*)
                local header=${1#--header=}
                shift
                ;;

            --max-nbr=?*)
                # maximum legal value for entry
                local max_entry_nbr=${1#--max-nbr=}
                shift
                ;;


            --col-count=?*)
                # The number of newspaper-style columns
                # (default is 2)
                local col_count=${1#--col-count=}
                shift
                ;;

    
            *)
                gshc_err_print "${WARN_UNEXPECTED_OPTION} $1 (in gshc_select_row)"
                shift
                ;;
    
        esac
    
    done;


    # clean entry for col_count to remove alpha
    local col_count=`echo "$col_count"|tr -d "[[:alpha:][:punct:][:space:]]"`
    if (test -z "$col_count"); then
        gshc_err_print "WARNING: invalid column count in gshc_select_row().  Using 2."
        local col_count=2
    fi

    if (test -z "$input_fname");then
        gshc_err_print "${ERR_MISSING_FILE_NAME} (gshc_select_row)"
        return 12
    fi

    if !(test -f "$input_fname");then
        gshc_err_print "${ERR_NOT_A_FILE} ${input_fname}"
        return 12
    fi

    # DOUBLE CHECK THIS--DO I NEED TO INCLUDE THE COUNT AFTER
    # POSSIBLE LINE WRAPPING?
    ##local row_count=$(wc -l "$input_fname"|cut -d ' ' -f 1)
    local orig_row_count=`gshc_line_count "$input_fname"`

    if (test $orig_row_count -eq 0); then
        gshc_err_print "ERROR. The input file for gshc_select_row() is empty:"
        gshc_err_print  "$input_fname"
        return 12
    fi

    if (test -z "${max_entry_nbr}"); then
        # The caller did not specify the maximum input
        # number, so assume it to be the number of
        # rows in the input file.
        max_entry_nbr=$orig_row_count
    fi

    if (test $orig_row_count -lt 1000); then
        # The automatic line numbers are always based on the
        # the number of original input rows (and should be
        # disabled otherwise).
        local nl_width=3
    else
        local nl_width=5
    fi

    if (test "${add_line_nbrs}" = 'T'); then
        gshc_installed_check "nl"
        if !(gshc_is_installed 'nl'); then
            gshc_err_print "${ERR_PGM_REQUIRED} (pgm=nl, script=gshc_select_row)"
            return 12
        fi
    fi

    local choice=0 # Selected item number

    while (test "$choice" = "0"); do
        # This is the main loop that displays the text
        # and prompts the user to enter a number.
        # If the user enters 'n' or 'p', then scroll
        # to the next or previous screen.
        # The screen-measuring stuff is inside the loop so that
        # if the user selects 'n' or 'p' or anything that
        # causes a new screen, the display will adapt to
        # the new screen size.

        gshc_dprint 3 "TOP OF gshc_select_row main loop for instance ${tmp_fname1}"
        # -  -  -  -  -  -  - 
        # Some screen-size settings
        local s_rows=`stty size|cut -d ' ' -f 1`
        local s_cols=`stty size|cut -d ' ' -f 2`
        local col_width=$(( $s_cols / ${col_count}  - 1 ))
        # determine how many display lines the header will occupy
        # when folded onto the screen:
        # (drop the trailing \n from hdr_hgt but not prompt)
        local formatted_hdr="`gshc_display_msg "${header}"`"
        local hdr_hgt=`echo -e "${formatted_hdr}"|wc -l |cut -d ' ' -f 1`
        #local hdr_hgt=$(( $hdr_hgt -  1 ))
    
        local prompt_hgt=`echo -e "${MSG_SCREEN_NAV}"|fold -w $col_width|wc -l |cut -d ' ' -f 1`


        if (test "$truncate" = "T"); then
            # truncate each line if it is too long
            gshc_dprint 3 "truncating long lines"
            if (test "${add_line_nbrs}" = 'T'); then
                if [ -f /etc/freebsd-update.conf ]  || [ -f /bsd ]; then
                    # freebsd version .. no \t:
                    cat "$input_fname"|nl --number-width=$nl_width \
                        |cut -b 1-${col_width} > "$tmp_fname1"
                else
                    cat "$input_fname"|nl --number-width=$nl_width|sed -e 's/\t/ /' \
                        |cut -b 1-${col_width} > "$tmp_fname1"
                fi
            else
                # The truncate option overrides the format_body_text option.
                if [ -f /etc/freebsd-update.conf ]  || [ -f /bsd ]; then
                    # freebsd version .. no \t:
                    cat "$input_fname" \
                        |cut -b 1-${col_width} > "$tmp_fname1"
                else
                    cat "$input_fname"|sed -e 's/\t/ /' \
                        |cut -b 1-${col_width} > "$tmp_fname1"
                fi
            fi
        else
            # fold (wrap) each line if it is too long
            gshc_dprint 3 "folding long lines"
            if (test "${add_line_nbrs}" = 'T'); then
                if [ -f /etc/freebsd-update.conf ]  || [ -f /bsd ]; then
                    # freebsd version .. no \t:
                    cat "$input_fname"|nl --number-width=$nl_width \
                        |fold -w $col_width    > "$tmp_fname1"
                else
                    cat "$input_fname"|nl --number-width=$nl_width|sed -e 's/\t/ /' \
                        |fold -w $col_width    > "$tmp_fname1"
                fi
            else
                # There are no automatic line numbers.
                # This is assumed to require formatting with gshc_display_msg???
                # ADD WARNING IF format_body_text is not set?
                if (test "${format_body_text}" = 'T'); then
                    gshc_dprint 3 "Preparing formatted body text."
                    # The call to gshc_display_msg will neatly wrap/fold
                    # the text to the current screen width.
                    # Process the file without passing through arrays (because
                    # that will add the IFS sep char again and cause errors).
                    ##gshc_display_msg "`cat "$input_fname"`"|sed -e 's/\t/ /'  > "$tmp_fname1"
                    gshc_display_msg "`cat "$input_fname"`"  > "$tmp_fname1"
                else
                    gshc_dprint 3 "Preparing unformatted, folded body text."
                    # fold/wrap the rows, but do not add line numbers
                    ##cat "$input_fname"|sed -e 's/\t/ /' \
                    ##    |fold -w $col_width    > "$tmp_fname1"
                    cat "$input_fname" \
                        |fold -w $col_width    > "$tmp_fname1"
                fi
            fi
        fi

        # 'display_hgt' is the number of DATA rows to display
        # (not counting the header or footer)
        local display_hgt=$(( ${s_rows} - ${hdr_hgt} - ${prompt_hgt}))

        if (test $display_hgt -lt 2); then
            # If your screen is to short, too bad.
            display_hgt=2
        fi

        # 'tail_hgt' is the number of lines to select
        # before column-wrapping the displayed text.
        local tail_hgt=`echo "${display_hgt} * ${col_count}"|bc`
        local bottom_row=`echo "${screen_idx} * ${display_hgt} * ${col_count}"|bc`

        local displayable_row_count=`gshc_line_count "$tmp_fname1"`
        # I think the max_screen_idx is a screen-nbr-index, and would depend
        # on the number of displayable rows, not the oringal rows.
        local max_screen_idx=`echo "${displayable_row_count}/${tail_hgt} +1"|bc`
        # -  -  -  -  -  -  - 

        # debug info
        gshc_dprint 3 "-=---=-=-=-=--=--=-= gshc_select_row()..."
        gshc_dprint 3 "input_fname=$input_fname"
        gshc_dprint 3 "orig_row_count=$orig_row_count"
        gshc_dprint 3 "nl_width=$nl_width"
        gshc_dprint 3 "s_rows=${s_rows}; s_cols=${s_cols};"
        gshc_dprint 3 "display_hgt=${display_hgt}; tail_hgt=${tail_hgt}"
        gshc_dprint 3 "bottom_row=${bottom_row}"
        gshc_dprint 3 "-=---=-=-=-=--=--=-="

        # Use head and tail to select some rows to display,
        # then use 'pr' to format it into two columns:
        # (testing -added -T (to show tabs as ^I) for the first 'cat', Feb 2014)
        if [ -f /etc/freebsd-update.conf ]  || [ -f /bsd ]; then
            # freebsd version:
            cat -T "$tmp_fname1" \
                |head -n $bottom_row  |tail -n $tail_hgt \
                |pr    -${col_count} -h "" -s\| \
                 -w $s_cols  -l $display_hgt  > "$tmp_fname2"
        else
            cat -T "$tmp_fname1" \
                |head -n $bottom_row  |tail -n $tail_hgt \
                |pr    --header "" --columns $col_count --sep-string='|' \
                 --width=$s_cols -T -l $display_hgt  > "$tmp_fname2"
        fi

        # Display the header... never truncate it
        gshc_display_msg "${header}" 
        # Display the portion of the body of the menu that fits on the screen.
        cat "$tmp_fname2"
        gshc_get_txt_input "${MSG_SCREEN_NAV}" 

        gshc_dprint 3 "gshc_select_row, user entered: $G_TXT"

        case "$G_TXT" in
            'q' | 'Q')
                # user is quitting
                gshc_dprint 3 "User chose the Q (quit) option in gshc_select_row()"
                choice='q'
                break;
                ;;
            'f' | 'F')
                local screen_idx=1
                ;;
            'l' | 'L')
                # last screen
                local screen_idx=$max_screen_idx
                ;;
            'n' | 'N')
                local screen_idx=$(( $screen_idx + 1 ))
                if (test $screen_idx -gt $max_screen_idx); then
                    local screen_idx=$max_screen_idx
                fi
                ;;
            'p' | 'P')
                local screen_idx=$(( $screen_idx - 1 ))
                if (test $screen_idx -lt 1); then
                    local screen_idx=1
                fi
                ;;
            'c' | 'C')
                gshc_get_nbr_input "Enter the number of display columns (1-6): " 6
                col_count=${G_NBR}
                ;;
            't' | 'T')
                # toggle truncate lines
                if (test "$truncate" = "T"); then
                    local truncate='F'
                else
                    local truncate='T'
                fi
                local screen_idx=1
                ;;
            '?')
                ###clear;
                gshc_select_menu_entry "${MSG_SCREEN_NAV_HELP}" "${MSG_SCREEN_NAV_HELP_HDR}" 
                G_TXT=""
                local choice=0; # stay in the loop until a real selection is made.
                ;;
            *)
                # Clean the entry to remove unwanted characters.
                local choice=`echo "$G_TXT"|tr -d "[[:alpha:][:punct:][:space:]]"`
            
                if (test -z "$choice"); then
                    # The user entered non-umeric junk that was delete by the 'tr'
                    # command above: set the 'choice' to zero to force another loop.
                    local choice=0
                ##elif (test $choice -gt $orig_row_count); then
                elif (test $choice -gt $orig_row_count); then
                    gshc_err_print "${WARN_INVALID_NBR}"
                    local choice=0
                    gshc_pause    
                fi
                ;;
        esac
    done;

    if (test "$choice" = "q"); then
        G_NBR=0
    else
        if (test "$choice" = "0"); then
            # User quit instead of selecting a value.
            # The VM_NAME varialbe will be blank.
            gshc_err_print "${MSG_INVALID_SEL}"
            return 13        
        fi
        G_NBR=$choice # set global variable
    fi
    return 0
}
#------------------------------------------------------------
#------------------------------------------------------------
#------------------------------------------------------------
gshc_multi_select(){
    # Given a multe-part numeric selection like this:
    # '1,3,5,7-9,11,5-20'
    # set the global variable  G_CHOICE_ARRAY
    # to the full set of individual integers that
    # were requested.

    # Function:
    # parse using commas, then within each chunk, parse by '-'.
    declare -a array_c

    local parse_c=$(echo "array_c=($1)"|tr ',' ' ')
    # use eval() to define the array_c variable.
    eval ${parse_c}
    gshc_dprint 3 "multi_select: first array parse ${array_c[*]}"

    i=0 # i is the index for G_CHOICE_ARRAY
    j=0
    while (test $j -lt ${#array_c[*]}); do
        r="${array_c[$j]}"
        range_check=$(echo "$r"|grep '^[0-9]*[-][0-9]*$')
        if (test -z "${range_check}"); then
            # it is not a range
            G_CHOICE_ARRAY[$i]=$r
            i=$(( $i + 1 ))
            
        else
            # it is a range
            rng_min=$(echo "$r"|sed -e 's/^\([0-9]*\)[[:print:]]*/\1/')
            rng_max=$(echo "$r"|sed -e 's/^\([0-9]*\)[-]\([0-9]*\)*/\2/')
            k=$rng_min
            while (test $k -le ${rng_max}); do
                # Load each integer from min to max, inclusive.
                G_CHOICE_ARRAY[$i]=$(( $k ))
                i=$(( $i + 1 ))
                k=$(( $k + 1 ))
            done
        fi
        j=$(( $j + 1 ))
    done
    gshc_dprint 4 "multi-select array at the end: ${G_CHOICE_ARRAY[*]}"

    return 0
} # end gshc_multi_select
#------------------------------------------------------------
#------------------------------------------------------------
gshc_select_line(){
# THIS WILL REPLACE GSHC_SELECT_ROW.  THIS VERSION READS
# A SINGLE VARIABLE THAT CONTAINS EMBEDDED EOLS OR it 
# can read a file!
# THIS IS BEING MODIFIED TO SET G_CHOICE_ARRAY GLOBAL VARIABLE
# IF THE USER ENTERS MORE THAN ONE NUMBER ON THE COMMAND LINE.
# G_NBR WILL BE SET TO -3 IF AN ARRAY IS BEING RETURNED.
    # Given a filename, show a list of the rows in that file
    # (assumed to be text).  By default, this function will
    # add line numbers to each input row,
    # and prompt the user to select one by entering a number.
    # This will set the global variable G_NBR with the selected row nbr.
    # This will also set G_TXT to the value of that line.
    # or zero if the user did not select anything.
    # The user can scroll to the next an previous screen, or 
    # first or last screen if the data is too big to fit on one screen.
    # The user can adjust options for the number of newspaper-style
    # columns displayed and line-truncation.
    #
    # TO DO: allow the caller to specify context-sensitive
    # help text and an override prompt text.

    # screen_idx select the 'page' within the menu to display
    # if it is longer than one screen.

    gshc_dprint 6 "Top of gshc_select_line"
    local multi_select_allowed='F'
    local screen_idx=1
    local input_type=''
    local truncate='T' # default is True
    local add_line_nbrs='T' # default is True
    local format_body_text='F' #call gshc_display_msg for the body of the menu
    local col_count=2 # default number of newspaper-style columns



    while [ "$1" != "${1##[-+]}" ]; do
        ###clear
        gshc_dprint 1 "top of gshc_select_line ARG loop for option $1"
        case $1 in
            '')   gshc_err_print "$0: Usage: gshc_select_line [{--text='your text' \\" 
                        gshc_err_print " --file-name=FNAME}] [--max-nbr=NBR] [--multi-select] \\"
                        gshc_err_print "--header='HEADER/TITLE' [--col_count=2] [{--truncate, --no-truncate}]"
                        gshc_err_print "where 'col-count' is the number of newspaper-style"
                        gshc_err_print "columns displayed."
                         return 1;;
            
            --truncate)
                truncate='T';
                shift
                ;;

            --no-truncate)
                truncate='F';
                shift
                ;;

            --multi-select)
                multi_select_allowed='T';
                shift
                ;;


            --no-line-nbrs)
                add_line_nbrs='F';
                shift
                ;;

            --format-body-text)
                # This invokes the fmt program to make
                # the menu look nice.
                format_body_text='T';
                shift
                ;;

            --file-name=?*)
                local input_fname=${1#--file-name=}
                shift
                ;;

            --text=?*)
                local input_text=${1#--text=}
                shift
                ;;
            --header=?*)
                local header=${1#--header=}
                shift
                ;;

            --max-nbr=?*)
                # maximum legal value for entry
                local max_entry_nbr=${1#--max-nbr=}
                shift
                ;;

            --col-count=?*)
                # The number of newspaper-style columns
                # (default is 2)
                local col_count=${1#--col-count=}
                shift
                ;;

            --user-input=?*)
                # For unit testing - enter this number as if
                # the user entered it interactively
                local user_input=${1#--user-input=}
                shift
                ;;

            --screen-width=?*)
                # For unit testing - the number of characters
                # to display on the screen.
                local screen_width=${1#--screen-width=}
                shift
                ;;
    
            *)
                gshc_err_print "${WARN_UNEXPECTED_OPTION} $1 (in gshc_select_line)"
                gshc_err_print "It could be that the value associated with the key was blank."
                return 12
                shift
                ;;
    
        esac
    
    done;


    # clean entry for col_count to remove alpha
    local col_count=`echo "$col_count"|tr -d "[[:alpha:][:punct:][:space:]]"`
    if (test -z "$col_count"); then
        gshc_display_err "WARNING: invalid column count in gshc_select_line().  Using 2."
        local col_count=2
    fi

    # Check if the user sent either text or a file name
    if (test -z "${input_text}"); then
        if (test -z "$input_fname");then
            # both text in input file name are blank.
            gshc_display_err "${ERR_MISSING_TEXT_AND_FILE} (gshc_select_line)"
            gshc_err_print "perhaps the value of --text or --file-name was blank."
            return 12
        else
            local input_type='file'
            if !(test -f "$input_fname");then
                gshc_display_err "${ERR_NOT_A_FILE} ${input_fname}"
                return 12
            fi
        fi
    else
            local input_type='text'
    fi


    if (test "${input_type}" = 'text'); then
        the_text="${input_text}"
        unset input_text
    else
        # the user sent an input file name
        the_text="`cat "${input_fname}"`"
        unset input_text
    fi

    gshc_dprint 6 "gshc_select_line B"
    # DOUBLE CHECK THIS--DO I NEED TO INCLUDE THE COUNT AFTER
    # POSSIBLE LINE WRAPPING?
    #######local orig_row_count=`gshc_line_count "$input_fname"`
    if [ -f /etc/freebsd-update.conf ]  || [ -f /bsd ]; then
        # freebsd version:
        local orig_row_count=$(echo "${the_text}"|wc -l |tr -s ' '|cut -d ' ' -f 2)
    else
        # linux version:
        local orig_row_count=$(echo "${the_text}"|wc -l |cut -d ' ' -f 1)
    fi

    if [ -z "${orig_row_count}" ]; then
        echo "Error. I could not get the row count of the text to display, which was: < ${the_text} >"
        exit 18
    else
        if (test $orig_row_count -eq 0); then
            gshc_display_err "ERROR. The input file for gshc_select_line() is empty:"
            if (test "${input_type}" = "file"); then
                gshc_display_err "$input_fname"
            fi
            return 12
        fi
    fi

    if (test -z "${max_entry_nbr}"); then
        # The caller did not specify the maximum input
        # number, so assume it to be the number of
        # rows in the input file.
        max_entry_nbr=$orig_row_count
    fi

    if (test $orig_row_count -lt 1000); then
        # The automatic line numbers are always based on the
        # the number of original input rows (and should be
        # disabled otherwise).
        local nl_width=3
    else
        local nl_width=5
    fi

    if (test "${add_line_nbrs}" = 'T'); then
        gshc_installed_check "nl"
        if !(gshc_is_installed 'nl'); then
            gshc_err_print "${ERR_PGM_REQUIRED} (pgm=nl, script=gshc_select_line)"
            return 12
        fi
    fi

    local choice=0 # Selected item number

    gshc_dprint 6 "gshc_select_line C"

    while (test "$choice" = "0"); do
        # This is the main loop that displays the text
        # and prompts the user to enter a number.
        # If the user enters 'n' or 'p', then scroll
        # to the next or previous screen.
        # The screen-measuring stuff is inside the loop so that
        # if the user selects 'n' or 'p' or anything that
        # causes a new screen, the display will adapt to
        # the new screen size.

        local choice=''
        local choice_clean=''
        local multi_check=0

        gshc_dprint 3 "TOP OF gshc_select_line main loop for instance ${tmp_fname1}"
        # -  -  -  -  -  -  - 
        # Some screen-size settings
        local s_rows=`stty size|cut -d ' ' -f 1`
        if (test -z "${screen_width}"); then
            local s_cols=`stty size|cut -d ' ' -f 2`
        else
            # use the width from the user option (for unit testing)
            local s_cols=${screen_width}
        fi
        local col_width=$(( $s_cols / ${col_count}  - 1 ))
        # determine how many display lines the header will occupy
        # when folded onto the screen:
        # (drop the trailing \n from hdr_hgt but not prompt)
        local formatted_hdr="`gshc_display_msg "${header}"`"
        local hdr_hgt=`echo -e "${formatted_hdr}"|wc -l |cut -d ' ' -f 1`
        #local hdr_hgt=$(( $hdr_hgt -  1 ))
    
        local prompt_hgt=`echo -e "${MSG_SCREEN_NAV}"|fold -w $col_width|wc -l |cut -d ' ' -f 1`


        if (test "$truncate" = "T"); then
            # truncate each menu line if it is too long
            gshc_dprint 3 "truncating long lines"
            if (test "${add_line_nbrs}" = 'T'); then
                ###local tmp1="`echo "${the_text}"|nl --number-width=$nl_width \
                ###    |sed -e 's/\t/ /' \
                ###    |cut -b 1-${col_width}`"
                local tmp1="`echo "${the_text}"|nl --number-width=$nl_width \
                    |cut -b 1-${col_width}`"
            else
                # The truncate option overrides the format_body_text option.
                ##local tmp1="`echo "${the_text}"|sed -e 's/\t/ /' \
                ##    |cut -b 1-${col_width}`"
                local tmp1="`echo "${the_text}" \
                    |cut -b 1-${col_width}`"
            fi
        else
            # fold (wrap) each menu line if it is too long
            gshc_dprint 3 "folding long lines"
            if (test "${add_line_nbrs}" = 'T'); then
                # Add line numbers -- assume that format_body_text is not set.
                gshc_dprint 3 "adding line nbrs to folded lines"
                ###local tmp1="`echo "${the_text}"|nl --number-width=$nl_width \
                ###    |sed -e 's/\t/ /' \
                ###    |fold -w $col_width`"
                local tmp1="`echo "${the_text}"|nl --number-width=$nl_width \
                    |fold -w $col_width`"
            else
                # There are no automatic line numbers.
                gshc_dprint 3 "NOT adding line nbrs to folded lines"
                if (test "${format_body_text}" = 'T'); then
                    gshc_dprint 3 "Preparing formatted body text."
                    # The call to gshc_display_msg will neatly wrap/fold
                    # the text to the current screen width.
                    # This code will allow for wrapped, formatted, newspaper
                    #    columns.
                    ###local tmp_no_tabs="`echo  "${the_text}"|sed -e 's/\t/ /'`"
                    local tmp_no_tabs="`echo  "${the_text}"`"
                    local tmp1="`gshc_display_msg "${tmp_no_tabs}" $col_width`"
                    unset tmp_no_tabs
                else
                    gshc_dprint 3 "Preparing unformatted, folded body text."
                    # fold/wrap the rows, but do not add line numbers
                    ###local tmp1="`echo "${the_text}"|sed -e 's/\t/ /' \
                    ###    |fold -w $col_width`"
                    local tmp1="`echo "${the_text}" \
                        |fold -w $col_width`"
                fi
            fi
        fi

        # 'display_hgt' is the number of DATA rows to display
        # (not counting the header or footer)
        local display_hgt=$(( ${s_rows} - ${hdr_hgt} - ${prompt_hgt} - 1 ))

        if (test $display_hgt -lt 2); then
            # If your screen is to short, too bad.
            display_hgt=2
        fi

        # 'tail_hgt' is the number of menu lines to select
        # before column-wrapping the displayed text.
        # It is sent to the 'tail' program.
        local tail_hgt=`echo "${display_hgt} * ${col_count}"|bc`
        local bottom_row=`echo "${screen_idx} * ${display_hgt} * ${col_count}"|bc`

        ## Mar 7 #local displayable_row_count=`gshc_line_count "$tmp_fname1"`
        local displayable_row_count=$(echo "${tmp1}"|wc -l|cut -d ' ' -f 1)
        # I think the max_screen_idx is a screen-nbr-index, and would depend
        # on the number of displayable rows, not the oringal rows.
        local max_screen_idx=`echo "${displayable_row_count}/${tail_hgt} +1"|bc`
        # -  -  -  -  -  -  - 

        # debug info
        gshc_dprint 3 "-=---=-=-=-=--=--=-= gshc_select_line()..."
        gshc_dprint 3 "input_fname=$input_fname"
        gshc_dprint 3 "orig_row_count=$orig_row_count"
        gshc_dprint 3 "nl_width=$nl_width"
        gshc_dprint 3 "s_rows=${s_rows}; s_cols=${s_cols};"
        gshc_dprint 3 "display_hgt=${display_hgt}; tail_hgt=${tail_hgt}"
        gshc_dprint 3 "bottom_row=${bottom_row}"
        gshc_dprint 3 ""
        gshc_dprint 3 "truncate=$truncate"
        gshc_dprint 3 "add line nbrs=$add_line_nbrs"
        gshc_dprint 3 "format body text=$format_body_text"
        gshc_dprint 3 "col count=$col_count"
        gshc_dprint 3 "-=---=-=-=-=--=--=-="

        # Use head and tail to select some rows to display,
        # then use 'pr' to format it into two columns:
        # (testing -added -T (to show tabs as ^I) for the first 'cat', Feb 2014).
        # tmp2 is the portion of the body of the menu that fits on the screen.
        # tmp1 is the text of the main menu (not including header/footer/prompt).
        if [ -f /etc/freebsd-update.conf ]  || [ -f /bsd ]; then
            # freebsd version:
            tmp2="`echo "${tmp1}" \
                |head -n $bottom_row  |tail -n $tail_hgt \
                |pr    -${col_count} -h ""  -s\| \
                 -w $s_cols   -l $display_hgt`"
        else
            tmp2="`echo "${tmp1}" \
                |head -n $bottom_row  |tail -n $tail_hgt \
                |pr    --header "" --columns $col_count --sep-string='|' \
                 --width=$s_cols -T -l $display_hgt`"
        fi

        # Display the header... never truncate it
        gshc_display_msg "${header}" 
        # Display the portion of the body of the menu that fits on the screen.
        echo "${tmp2}"
        # Show a count of current page/total pages for the menu
        little_footer="+(menu p. ${screen_idx}/${max_screen_idx})"
        echo "${little_footer}"|cut -b 1-$s_cols


        # -  -    -    -    -   --   Get the users' menu selection:
        if (test -z "$user_input"); then
            # If the unit testing input value is not available,
            # prompt the user.
            G_TXT=''
            while (test -z "${G_TXT}"); do
                # get a non-blank menu entry
                gshc_get_txt_input "${MSG_SCREEN_NAV}" 
            done
        else
            G_TXT="${user_input}"
        fi
        # WARNING: BECAUSE I SET 'CHOICE' HERE, I HAVE TO RESET IT TO 0 FOR ALL SCREEN NAVIGATION COMMANDS.
        choice="${G_TXT}" # raw input

        gshc_dprint 3 "gshc_select_line, user entered: $choice"

        case "$choice" in
            'q' | 'Q')
                # user is quitting
                gshc_dprint 3 "User chose the Q (quit) option in gshc_select_line()"
                choice_clean='q'
                break;
                ;;
            'f' | 'F')
                choice=0; # reset 'choice' to zero for all screen navigation to continue entry-loop.
                local screen_idx=1
                ;;
            'l' | 'L')
                # last screen
                choice=0; # reset 'choice' to zero for all screen navigation to continue entry-loop.
                local screen_idx=$max_screen_idx
                ;;
            'n' | 'N')
                choice=0; # reset 'choice' to zero for all screen navigation to continue entry-loop.
                local screen_idx=$(( $screen_idx + 1 ))
                if (test $screen_idx -gt $max_screen_idx); then
                    local screen_idx=$max_screen_idx
                fi
                ;;
            'p' | 'P')
                choice=0; # reset 'choice' to zero for all screen navigation to continue entry-loop.
                local screen_idx=$(( $screen_idx - 1 ))
                if (test $screen_idx -lt 1); then
                    local screen_idx=1
                fi
                ;;
            'c' | 'C')
                choice=0; # reset 'choice' to zero for all screen navigation to continue entry-loop.
                gshc_get_nbr_input "Enter the number of display columns (1-6): " 6
                col_count=${G_NBR}
                ;;
            't' | 'T')
                choice=0; # reset 'choice' to zero for all screen navigation to continue entry-loop.
                # toggle truncate lines
                if (test "$truncate" = "T"); then
                    local truncate='F'
                else
                    local truncate='T'
                fi
                local screen_idx=1
                ;;
            '?')
                ###clear;
                gshc_select_menu_entry "${MSG_SCREEN_NAV_HELP}" "${MSG_SCREEN_NAV_HELP_HDR}" 
                G_TXT=""
                local choice=0; # stay in the loop until a real selection is made.
                ;;
            *)
                # Process an expected numeric entry in $choice
                #
                local multi_check=0
                if (test "${multi_select_allowed}" = 'T'); then
                    # Check for numeric range entry (strict entry enforcement):
                    ### unset G_CHOICE_ARRAY
                    local choice_scrub=$(echo "${choice}"|tr -d "[[:alpha:]]")

                    # gshc_multi_select sets the global variable G_CHOICE_ARRAY.
                    gshc_multi_select "${choice_scrub}"
                    multi_check=${#G_CHOICE_ARRAY[*]}

                    if (test ${multi_check} -gt 1); then
                        gshc_dprint 4 "select_line: user selected multiple items: ${multi_check}."
                        # The user entered multiple items.
                        # G_CHOICE_ARRAY global variable was set by gshc_multi_check.
                        local choice_clean=-3 #reserved value for multi-item select
                    fi
                fi

                if (test ${multi_check} -lt 2); then
                    # This is normal selection of a single item.
                    # Clean the entry to remove unwanted characters.

                    # First kill the choice array to preven confusion later.
                    unset G_CHOICE_ARRAY
                    declare -a G_CHOICE_ARRAY

                    gshc_dprint 4 "select_line: user selected no more than one item."
                    local choice_clean=$(echo "$choice"|tr -d "[[:alpha:][:punct:][:space:]]")
                    if (test "${choice_clean}" != "${choice}"); then
                        echo "BAD CHARACTERS IN ENTRY: ${choice}"
                        return 12
                    fi

                    if (test -z "$choice_clean"); then
                        # The user entered non-umeric junk that was delete by the 'tr'
                        # command above: set the 'choice' to zero to force another loop.
                        local choice_clean=0
                    elif (test $choice_clean -gt $orig_row_count); then
                        # Run this check only for single selections.
                        echo "${WARN_INVALID_NBR}"
                        local choice_clean=0
                        gshc_pause    
                    fi
                fi
                ;;
        esac
        gshc_dprint 4 "select_line: after the big case statement"
    done;
    gshc_dprint 4 "select_line: after the big loop. choice=${choice}, choice_clean=${choice_clean}."

    if (test "$choice" = "q"); then
        G_NBR=0
    else
        if (test "$choice_clean" = "0"); then
            # User quit instead of selecting a value.
            # The VM_NAME varialbe will be blank.
            gshc_err_print "${MSG_INVALID_SEL}"
            G_NBR=0
            return 13        
        fi
        G_NBR=$choice_clean # set global variable
        gshc_dprint 3 "select_line: numeric choice is ${choice_clean} derived from ${choice}."
    fi

    # Select the chosen record and put the text into G_TXT global variable
    if (test ${multi_check} -gt 1); then
        G_TXT=''
        j=0
        
        while (test $j -lt ${#G_CHOICE_ARRAY[*]}); do
            # Accumulate lines of entry, spearted by newline. 
            local tmp_nbr=$(( ${G_CHOICE_ARRAY[$j]} ))
            local tmp_text="`echo "${the_text}"|head -n ${tmp_nbr}|tail -n 1`"

            gshc_dprint 4 "select_line multi-select, tmp nbr is ${tmp_nbr} and tmp text is ${tmp_text}"

            G_TXT=$(echo -e "${G_TXT}\n${tmp_text}")
            
            j=$(( $j + 1 ))
        done
    else
        G_TXT="`echo "${the_text}"|head -n $G_NBR|tail -n 1`"
    fi
    return 0
} # end of gshc_select_line
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
#
#                         NETWORK INTERFACES
#                       (e.g., network cards)
#
gshc_list_interfaces(){
    # Display all of the interface names such as "eth0" "lo" "vnet0"...
    # Note that 'sort -u' might be more portable than the 'uniq' program.
    if (gshc_is_installed "ip"); then
        ip link show|grep "^[0-9]" |cut -d':' -f 2|sed -e "s/^[[:space:]]*//"|sort -u
    else
        # use ifconfig
        ifconfig -s|grep -iv '^iface '|cut -d ' ' -f 1|sort -u
    fi
}

gshc_is_interface(){
    # Return 0 if the specified interfacce exists
    local FIND_IFACE="$1"
    local I_LIST="`gshc_list_interfaces`"

    if (test -z "`echo "${I_LIST}"|grep "^${FIND_IFACE}"`"); then
        # the interface does not exist
      return 12
    else
        # the interface exists
      return 0
    fi

}

gshc_select_interface(){
    # List interface names such as "eth0" "lo" "vnet0"...
    # and set the global variable G_IF_NAME with the 
    # name of the selected interface.
    # See also gshc_iface_status, gshc_is_interface, 
    # gshc_list_inerfaces, gshc_select_interface
    # gshc_iface_settings_good

    G_IF_NAME=""

    if [ -z "$1" ]; then
        local MY_PROMPT="Enter a number to select a network interface (or Q): "
    else
        local MY_PROMPT="$1"
    fi

    local IF_list="`gshc_list_interfaces`"
    # Mar 7 # echo "$IF_list"|sort|nl > /tmp/gshc_iflist.txt
    local iflist="`echo "$IF_list"|sort|nl`"

    # display the numbered list of interface names:
    # Mar 7 # cat /tmp/gshc_iflist.txt
    echo "${iflist}"

    # Mar 7 # local tmp_max=$(wc -l /tmp/gshc_iflist.txt |cut -d ' ' -f 1)
    local tmp_max=$(echo "${iflist}"|wc -l|cut -d ' ' -f 1)

    local IF_NBR=0;
    gshc_get_nbr_input "$MY_PROMPT" $tmp_max
    if (test "${G_NBR}" = "0"); then
        echo "${ERR_INVALID_IFACE_SEL}"
        return 13 
    fi


    IF_NBR=${G_NBR}
    if (test "$IF_NBR" = "0" || test -z "$IF_NBR"); then
        echo "${ERR_INVALID_IFACE_SEL}."
        G_IF_NAME=""
        return 13
    else
        if [ -f /etc/freebsd-update.conf ] || [ -f /bsd ]; then
            # freebsd version. the \t did not work        
            G_IF_NAME=$(echo "${iflist}"|cut -d ' ' -f 3 \
                |tail -n +${IF_NBR}|head -n 1);
        else
            ## G_IF_NAME=$(cat /tmp/gshc_iflist.txt|tr -s ' \t' ' '|cut -d ' ' -f 3 \
            ##    |tail -n +${IF_NBR}|head -n 1);
            G_IF_NAME=$(echo "${iflist}"|tr -s ' \t' ' '|cut -d ' ' -f 3 \
                |tail -n +${IF_NBR}|head -n 1);
        fi
    fi
    return 0
}
    
gshc_iface_status(){
    # Display "UP" or "DOWN" "UNKNOWN" for the selected interface name
    # or blank for invalid interface.
    # See also gshc_is_interface, gshc_list_inerfaces, gshc_select_interface,
    # gshc_iface_settings_good()

    local IF="$1"
    if (test -z "$IF"); then
        return 12
    fi

    ip link show "$IF"|sed -e "s/^[[:print:]]*state //"|cut -d ' ' -f 1\
        |head -n 1|tr "[[:lower:]]" "[[:upper:]]"

    return 0
}
gshc_iface_settings_good(){
    # THIS MIGHT NOT BE FINISHED??
    # MAYBE ADD FLAGS FOR WHICH INTERFACES TO CHECK?
    # ${HOME}/.gshc/gshc.conf defince EXTERNAL_IF, INTERNAL_IF, WAN
    # See also gshc_is_interface, gshc_list_inerfaces, gshc_select_interface,
    # gshc_iface_status, gshc_iface_settings_good()
    local I_LIST="`gshc_list_interfaces`"
    local tmp_good='T'

    if (test -z "${GSHC_PGM_PATH}"); then
        tmp_good='F'
        echo "${ERR_PATH_OPT_MISSING}"
    fi

    if !(test -r "${GSHC_PGM_PATH}"); then
        tmp_good='F'
        echo "${ERROR_CAN_NOT_READ_DIR} ${GSHC_PGM_PATH}"
    fi

    ### if (test -z "${EXTERNAL_IF}"); then
    ###     tmp_good='F'
    ###     gshc_err_print "ERROR, the EXTERNAL_IF variable is not defined in ${HOME}/.gshc/gshc.conf"
    ### fi
    ### 
    ### if (test -z "${INTERNAL_IF}"); then
    ###     tmp_good='F'
    ###     gshc_err_print "ERROR, the INTERNAL_IF variable is not defined in ${HOME}/.gshc/gshc.conf"
    ### fi

    if (test -z "${WAN}"); then
        tmp_good='F'
        echo "${ERR_MISSING_WAN_SETTING}"
    fi

    if (test -z "`echo "${I_LIST}"|grep "^${WAN}"`"); then
      # Interface not found
        echo "WAN=$WAN"
        echo "${ERR_BAD_WAN_SETTING}"
        tmp_good='F'
        #return 12
    fi

    if (test -z "`echo "${I_LIST}"|grep "^${DNS_DEV}"`"); then
    tmp_good='F'
        echo "${ERR_VAR_NOT_DEFINED} DNS_DEV"
  fi
  
    if (test -z "${VPN_IF}"); then
        tmp_good='F'
        echo "${ERR_VAR_NOT_DEFINED} VPN_IF"
    fi


    # -----------------------------------------------------------------------
    if !(test "${tmp_good}" = "T"); then
        # One or more option is missing or bad:
        echo "${ERR_BAD_IFACE}"
        gshc_list_interfaces
        return 12
    fi

    
    # Get the "UP" or "DOWN" flag for the WAN device.
    # (This is probably redundant)
    RSLT="`gshc_iface_status $WAN`"
    if (test -z "$RSLT"); then
        echo "${ERR_SELECT_NEW_WAN}"
        gshc_select_interface #sets G_IF_NAME
        WAN="$G_IF_NAME"
    fi

    return 0
}
# ------------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
gshc_select_filename(){
    # This will set a global variable called G_FILE_NAME with 
    # the selected file name.
    # This does not allow the user to navigate across directories.

    local DIR="$1"
    G_FILE_NAME=""
    local TMP_FILE=$(mktemp /tmp/gshc_XXXXXX)

    if (test -z "$DIR"); then
        # Directory to search defaults to current directory.
        local DIR="./"
    fi

    ###clear

    echo "${MSG_CURRENT_DIR} $DIR"
    gshc_get_txt_input "${MSG_ENTER_FNAME_OR_SELECT}"
    G_FILE_NAME="$G_TXT"

    if (test -d "$G_FILE_NAME"); then
        # The user entered a directory name,
        # display the contents.
        gshc_dprint 1 "gshc_select_filename: user entered a directory name: $G_FILE_NAME"
        local DIR="${G_FILE_NAME}"
    fi
    
    gshc_installed_check "nl"


    if (test -z "${G_FILE_NAME}"); then
        while (test -z "${G_FILE_NAME}"); do
            # Generate a list of files for this directory,
            # and call the gshc_select_row function to
            # have the user select a file or directory.
            # If the user selects a directory, refresh
            # the file list and go another iteration...
    
            # Initialize the file list with '..' so the user
            # can select it to go up a directory.
            echo ".." > "${TMP_FILE}"
    
            # WARNING: THIS IS HOAKEY: the first number in the listing
            # is an inode number that will have leading spaces if some
            # inode numbers have more digits than others.  The sed command
            # should fix it
            find "${DIR}" -maxdepth 1  -ls | sed -e 's/^[ ]*//' \
                |tr -s ' ' '|' \
                |cut -d '|' -f 11|xargs -I % basename %|sort >> "${TMP_FILE}"
    
            # gshc_select_line will set the global variable G_NBR
            gshc_select_line --file-name="${TMP_FILE}" \
                --header="Select a file.  Directory = $DIR"
    
            G_FILE_NAME="`cat "${TMP_FILE}"|tail -n +${G_NBR}|head -n 1`"
            if (test -d "${DIR}/${G_FILE_NAME}"); then
                if (gshc_is_installed 'realpath'); then
                    DIR="`realpath "${DIR}/${G_FILE_NAME}"`"
                else
                    DIR="${DIR}/${G_FILE_NAME}"
                fi
                gshc_dprint 1 "Changing directory in gshc_select_file: $DIR"
                G_FILE_NAME=""
            fi
        done;
    
        # Set the global variable with the selected file name
        # (Only if the interactive file-selection menu was shown):
        G_FILE_NAME=${DIR}/$(cat ${TMP_FILE}|tr -s ' \t' ' '|cut -d ' ' -f 1 \
            |tail -n +${G_NBR}|head -n 1);
    fi

    gshc_dprint 1 "gshc_select_filename: $G_FILE_NAME"
    return 0
}
# -----------------------------------------------------------------------------
#------------------------------------------------------------
gshc_select_device (){
    # Display devices that the user might want to attach
    # to a VM and prompt to select one.
    # Return the anser n $GSHC_DEV.
    # This will include things like /dev/sda1; /dev/mapper/luksMyDisk;
    # /dev/vda (in a VM);
    # and /dev/mapper/luks-134-134-1234-213-123
    #
    # ADD A SIMILAR FUNCTION THAT SHOWS ONLY
    # LOCKED LUKS DEVICES (MAYBE OPENED ONES ARE FLAGGED SOMEHOW).

    local tmp_MAX_ROWS=18
    local tmp_TOP_ROW_NBR=1
    local DEV_LIST_FNAME="/tmp/gshc_devicelist.txt"
    local DEV_LIST_FNAME2="/tmp/gshc_devicelist2.txt"

    # blkid requres root access
    if !(gshc_require_root); then
        echo "Error. You need to be root to run this."
        return 12
    fi
    blkid|cut -d ':' -f 1 > ${DEV_LIST_FNAME}
  if !(test -s "${DEV_LIST_FNAME}"); then
    echo "Error. There was no device list."
    return 12
  fi

    # add numbers to the device and display up to 18 of them
    nl ${DEV_LIST_FNAME} > "${DEV_LIST_FNAME2}"
    local tmp_R_COUNT=`wc -l ${DEV_LIST_FNAME} |cut -d ' ' -f 1`
    local MENU_CHOICE='n'

    if (test ${tmp_R_COUNT} -gt ${tmp_MAX_ROWS}); then
        # show only 18 rows at a time
        local tmp_BOT_ROW_NBR=`echo "$tmp_TOP_ROW_NBR + $tmp_MAX_ROWS - 1"|bc`
        ###### THIS PART IS VERY SLOW AND A GOOD EXAMPLE OF HOW SHELL SCRIPTS SUCK
        ###### for j in $(cat ${DEV_LIST_FNAME2}| tr -s ' \t' '|'); do
        ######     LINE_NBR=`echo "$j"|tr -s ' \t' ' '|cut -d '|' -f 2`
        ######     ##echo "line nbr: $LINE_NBR"
        ######     if (test  ${LINE_NBR} -ge ${tmp_TOP_ROW_NBR} && test  $LINE_NBR -le $tmp_BOT_ROW_NBR); then
        ######         echo "$j"|cut -d '|' -f 2,3
        ######     fi
        ###### done;
    else
        local tmp_BOT_ROW_NBR=$tmp_R_COUNT
    fi
    while (test "$MENU_CHOICE" = 'n' || test "$MENU_CHOICE" = 'p'); do
        # display the menu then prompt for input
        cat ${DEV_LIST_FNAME2}|head -n $tmp_BOT_ROW_NBR|tail -n $tmp_MAX_ROWS

        if (test ${tmp_R_COUNT} -gt ${tmp_MAX_ROWS}); then
            read -p "Enter a number to select the device or enter 'n' for the next screen: " MENU_CHOICE
        else
            read -p "Enter a number to select the device " MENU_CHOICE
        fi
        case $MENU_CHOICE in
            'n'|'N')
                MENU_CHOICE='n';;
            'p'|'P')
                MENU_CHOICE='p';;
        esac


        if (test "$MENU_CHOICE" = 'n'); then
            local tmp_BOT_ROW_NBR=`echo "$tmp_BOT_ROW_NBR + $tmp_MAX_ROWS"|bc`
        else
            if (test "$MENU_CHOICE" = 'p'); then
                local tmp_BOT_ROW_NBR=`echo "$tmp_BOT_ROW_NBR - $tmp_MAX_ROWS"|bc`
            else
                SAVE_MENU_CHOICE=$MENU_CHOICE
                MENU_CHOICE='q'
                break
                ##fi
            fi
        fi
        # prevent tiny bottome row number
        if (test $tmp_BOT_ROW_NBR -lt $tmp_MAX_ROWS); then
            local tmp_BOT_ROW_NBR=`echo "$tmp_TOP_ROW_NBR + $tmp_MAX_ROWS - 1"|bc`
        fi
        
    done;
        
    echo "${MSG_YOU_CHOSE} $SAVE_MENU_CHOICE ($GSHC_DEV)";
    # Keep the trailing space after SAVE_MENU_CHOICE to avoid duplicatge matches on the first
    # part of the number;
    GSHC_DEV=`cat ${DEV_LIST_FNAME2} |tr -s ' \t' ' '|grep "^ ${SAVE_MENU_CHOICE} "|cut -d ' ' -f 3`
    gshc_show_device_info $GSHC_DEV;
    return 0
}


gshc_format_nbr(){
    # This will format a number like 1,234.5 so that the
    # commas and decimal points reflect local customs
    # (in some countries it might be "1.234,5"
    # This does NOT add a separator to very long decimals.
    #
    # USAGE
    #   always pass a number inside quotes using USA 
    #   format of 1,234.5 and this will return the
    #   local version.
    local NBR="$1"
    echo "${G_NBR}"|tr  ",." "${GSHC_THOUSANDS_SEP}${GSHC_DEC}"
}


gshc_make_numeric(){
    # remove non-numeric characters from a variable
    # and echo the result (making it zero if there
    # was no numeric value in it).
        local tmp="`echo "$1"|sed -e 's/[^0-9]//g'`"
        if (test -z "$tmp"); then
            echo "0"
        else
            echo $tmp
        fi
}
gshc_var_is_int(){
    # This will check for either strings that are entered like numeric
    # digits (not allowing commas or periods)
    # and will also allow, but not require, the -i 'declare' option.
    #
    # Notes on the bash 'numeric' flag for environment variables.
    # 1) The 'i' flag for environment variables is set if
    #    the variable is declared like this:
    #    declare -i my_nbr
    # 2) If you declare the variable as an integer, it will
    #    stay an integer in all this cases:
    #    my_nbr=1 
    #    my_nbr=87685
    #    my_nbr=1 
    #    my_nbr=1 
    #    my_nbr=a  # will be set to numeric 0
    #    my_nbr='potato'  # will be set to numeric 0
    # 3) If you want to allow both numeric and character
    #    input from the command line, do not declare the variable
    #    with the -i option because you will loose the ability
    #    to detect the character inputs.
    # 4) If you want to collect both numeric and character
    #    input from the user, do NOT use the -i 'declare' option
    #    and test for alpha entry, then 
    #    scrub to make any left-overs numeric-looking strings.
    #
    # Example
    #  my_nbr=123
    #  gshc_var_is_int $my_nbr
    #
    #
    
    ##xxx # local attr="`declare -p $1|cut -d ' ' -f 2`"
    ##xxx # local iflag="${attr:1:2}"
    if (test -z $1); then
        return 12
    else
        # Remove non-numeric characters and save
        local tmp="`echo "$1"|sed -e 's/[^0-9]//g'`"
        if (test "$1" != "$tmp"); then
            # a difference between the two variables means
            # that there was at least one non-numeric value
            # that was removed and is not in $tmp.
            return 12
        else
            return 0
        fi
    fi

}

gshc_remove_trailing_slash(){
    #  This will echo the text in $1 after removing
    # any trailing slash

    if (test -z "$1"); then
        echo "ERROR. gshc_remove_trailing_slash input is blank."
        return 12
    fi

    str_len=${#1}
    ptr=$(( ${str_len} - 1 )) 
    last_char=${1:$ptr:$str_len}

    if (test "${last_char}" = '/'); then
        # Show all but the last character
        echo "${1:0:$ptr}"
    else
        # show the original string
        echo "${1}"
    fi
    gshc_dprint 6 "remove slash input was $1"
    return 0
}

gshc_add_trailing_slash(){
    #  This will echo the text in $1 after adding
    # a trailing slash, if there is not one there already.

    if (test -z "$1"); then
        echo "ERROR. gshc_add_trailing_slash input is blank."
        return 12
    fi

    gshc_dprint 6 "add slash input was $1"
    echo "`gshc_remove_trailing_slash $1`/"
    return 0
}

#------------------------------------------------------------
#
#  Part III: (previously LUKS, but now just a few renainders
#
#

gshc_config_array_parse(){
    # This will use the global array GSHC_ARRAY_TMP
    # as input and treat it as though it were a config
    # file that has entries like this:
    #  [screen]
    #  height=24
    #  width=80
    #
    #  [color]
    #  bg=black
    #  fg=white
    #
    # This script will print/echo the content of the requested
    # section without returning comments or blank lines.
    #
    # Display of shell arrays is affected by the $IFS variable.
  # Save the IFS, change it to put newline first, then save
  # my array stuff so that it has newlines, then restore the IFS.
    #
    # Example usage 1:
    #  ## Read a regular config file and grab the section
    #  ## called HS_KEYS
    #  readarray -t GSHC_ARRAY_TMP <<<"`cat /tmp/x.config`"
    #  my_opt="`gshc_config_array_parse "HS_KEYS"`"
    #  eval "$my_opts"
    #
    # Example usage 2:
    #  ## process an array that already contains
    #  ## the contents of a config file:
    #  IFSSAVE="$IFS"  # this is the "Field Separator" character list
    #  IFS="`echo "|  "|tr '|' '\n'`"
    #  GSHC_ARRAY_TMP="${TMP[*]}"
    #  IFS="$IFSSAVE"
    #  my_opt="`gshc_config_array_parse "HS_KEYS"`"
    #  eval "$my_opts"


    SECT="$1"

    if (test -z "$SECT"); then
        gshc_err_print "ERROR $0. the gshc_config_array_parse command needs an options name."
        return 12
    fi

  local IFSSAVE="$IFS"
  IFS="`echo "|  "|tr '|' '\n'`"
  local tmp_array="${GSHC_ARRAY_TMP[*]}"
  IFS="$IFSSAVE"

    # The main sed command below:
    #   Use the -n option to sed to avoid printing each line.
    #   Use the // syntax to identify the
    #   starting line, 
    #   Use the ',//' syntax to identify the subsequent line.
    #   (warning, if many lines match the starting criteria,
    #   the results are unpredictable).
    #   Use the 'H' command to 'hold' the lines,
    #   Use the 'g' command to get them?
    #   Use the $p command to print the held lines when the last
    #   of the input lines is done (the '$' means the end of file?).
    # the other commands below:
    #   * exclude lines that start with the '[' character,
    #   * use sed to delete any comments that start with '#'.
    #   * use sed to erase the spaces in a line that contains
    #     only whitespace.
    #   * use sed to remove trailing whitespace (in part to correct
    #     for trailing comments).
    #   * use sed to delete whitespace from lines that contain only whitespace. 
    #   * exclude lines that are blank, including lines that I made
    #     blank using the sed commands above ('^$' means the start of the
    #     line is next to the end of the line),

    echo "${tmp_array[*]}" \
        |sed -n -e  "/^[[]${SECT}[]]/,/^[[]/H" -e "g" -e "\$p" \
        |grep -v "^[[]"| grep -v "^[#]" \
        |sed -e "s/[#][[:print:]]*//"|sed -e "s/^[[:space:]]*$//" \
        |sed -e "s/[[:space:]]*$//"|grep -v "^$"

    ## echo 'testing. the end'

}


 ----------------------------------------------------------------------
#------------------------------------------------------------------------
#------------------------------------------------------------------------
#------------------------------------------------------------------------
#------------------------------------------------------------
#------------------------------------------------------------
gshc_select_filename2(){
# TEST VERSION THAT SPLITS DIRECTORIES AND FILES
    # This will set a global variable called G_FILE_NAME with 
    # the selected file name.
    # This does not allow the user to navigate across directories.

    local DIR="$1"
    local TMP_FILE_D=$(mktemp /tmp/gshc_sfD_XXXXXX)
    local TMP_FILE_F=$(mktemp /tmp/gshc_sfF_XXXXXX)
    local TMP_FILE_ALL=$(mktemp /tmp/gshc_sfA_XXXXXX)

    if (test -z "$DIR"); then
        # Directory to search defaults to current directory.
        local DIR="./"
    fi

    ###clear

    echo "The current directory is: $DIR"
    gshc_get_txt_input "Enter a filename (or ENTER to select): "
    G_FILE_NAME="$G_TXT"

    if (test -d "$G_FILE_NAME"); then
        # The user entered a directory name,
        # display the contents.
        gshc_dprint 1 "select_filename: user entered a directory name: $G_FILE_NAME"
        local DIR="${G_FILE_NAME}"
    fi
    
    gshc_installed_check "nl"


    G_FILE_NAME=""
    while (test -z "${G_FILE_NAME}"); do
        # Generate a list of files for this directory,
        # and call the gshc_select_line function to
        # have the user select a file or directory.
        # If the user selects a directory, refresh
        # the file list and go another iteration...

        # Initialize the file list with '..' so the user
        # can select it to go up a directory.
        echo ".." > "${TMP_FILE_D}"

        find "${DIR}" -maxdepth 1 -type d  -ls |tr -s ' ' '|' \
            |cut -d '|' -f 11|xargs -I % basename %|sort >> "${TMP_FILE_D}"

        find "${DIR}" -maxdepth 1 -type f -ls |tr -s ' ' '|' \
            |cut -d '|' -f 11|xargs -I % basename %|sort >> "${TMP_FILE_F}"

        gshc_dprint 1 "select_file2 using filenames  ${TMP_FILE_D} ${TMP_FILE_F}"
        cat "${TMP_FILE_D}" "${TMP_FILE_F}" > "${TMP_FILE_ALL}"

        # Note: gshc_select_row2 is a special select_row function that takes two lists of files.
        gshc_select_row2 "${TMP_FILE_D}" "${TMP_FILE_F}" \
            "Select a file.  Directory = $DIR"

        G_FILE_NAME="`cat "${TMP_FILE_ALL}"|tail -n +${G_NBR}|head -n 1`"
        if (test -d "${DIR}/${G_FILE_NAME}"); then
            if (gshc_is_installed 'realpath'); then
                DIR="`realpath "${DIR}/${G_FILE_NAME}"`"
            else
                DIR="${DIR}/${G_FILE_NAME}"
            fi
            gshc_dprint 1 "select_fname: Changing directory in gshc_select_file: $DIR"
            G_FILE_NAME=""
        fi
    done;

    # Set the global variable with the selected file name
    G_FILE_NAME=${DIR}/$(cat ${TMP_FILE}|tr -s ' \t' ' '|cut -d ' ' -f 1 \
        |tail -n +${G_NBR}|head -n 1);

    gshc_dprint 1 "gshc_select_filename: $G_FILE_NAME"
    return 0
}
#------------------------------------------------------------
gshc_select_row2(){
    # Given two filenames, one for a directory listing and one
    # for a file listing,
    # show a list of the rows in that file
    # (assumed to be text) and prompt the user to select one.
    # Set the global variable G_NBR with the selected row nbr.
    # or zero if the user did not select anything.
    # Maybe show multi-column format if posible.

    local screen_idx=1
    # The header is a 1-line title
    local hdr_hgt=1

    local fname_d="$1"
    local fname_f="$2"
    local header="$3"

    gshc_dprint 3 "gshc_select_row2 files: ${fname_d} ${fname_f}"

    local footer="q=quit, n=next, p=prev, c=col count, g=goto dir"

    local tmp_fname_d="`mktemp /tmp/gshc_srd_XXXX`"
    local tmp_fname_dcolor="`mktemp /tmp/gshc_srd2_XXXX`"
    local tmp_fname_f="`mktemp /tmp/gshc_srf_XXXX`"
    # 'display' is the ful list of data that contains color
    # codes.
    local tmp_fname_display="`mktemp /tmp/gshc_srdisplay_XXXX`"
    # 'chunk' is the subset of the displayable data that will
    # fit on one screen and that has color codes.
    local tmp_fname_chunk="`mktemp /tmp/gshc_srdisplay_XXXX`"
    # 'data' is the full list without color codes.
    local tmp_fname_data="`mktemp /tmp/gshc_srdata_XXXX`"


    if !(test -f "$fname_d");then
        echo "${ERR_NOT_A_FILE} $fname_d"
        return 12
    fi

    if !(test -f "$fname_f");then
        echo "${ERR_NOT_A_FILE} $fname_f"
        return 12
    fi

    local row_count_d=$(wc -l "$fname_d"|cut -d ' ' -f 1)
    local row_count_f=$(wc -l "$fname_f"|cut -d ' ' -f 1)
    local row_count_all=$(( $row_count_d + $row_count_f ))

    if (test $row_count_f -lt 1000 && test $row_count_d -lt 1000); then
        nl_width=3
    else
        nl_width=5
    fi

    gshc_installed_check "nl"
    if !(gshc_is_installed 'nl'); then
        echo "${ERR_PGM_REQUIRED} nl (gshc_select_row2)."
        return 12
    fi

    gshc_dprint 3  "tmp_fname_d=$tmp_fname_d"
    gshc_dprint 3  "tmp_fname_dcolor=${tmp_fname_dcolor}"
    gshc_dprint 3 "tmp_fname_f=$tmp_fname_f"
    gshc_dprint 3 "tmp_fname_display=$tmp_fname_display"
    gshc_dprint 3 "tmp_fname_data=$tmp_fname_data"

    # Number the lines, and replace only the first tab,
    cat "$fname_d"|nl --number-width=$nl_width|sed -e "s/\t/ /" \
        > "$tmp_fname_d"

    # then use sed to add some codes at the start and end
    # of the line to produce color (put the closing color command
    # before the trailing tab characters).
    # The directory names are followed by lots of white space so that
    # the pr program will truncate the spaces and thereby have
    # a better chance of putting the column separator in the correct
    # place.  Without the trailing sapces, the pr program uses
    # tabs, which are calculated incorrectly due to the 
    # control characters for color.
    s_tmp="                                            "
    spaces="${s_tmp}${s_tmp}${s_tmp}"
    cat "$tmp_fname_d"|sed -e 's/^/\x1b[38;5;34m/' \
        -e 's/\([[:space:]]*\)$/\x1b[0m................................................................................/' \
        > "$tmp_fname_dcolor"

    # Number the lines for regular files, and replace only the first tab.
    cat "$fname_f"|nl --number-width=$nl_width \
        --starting-line-number=$(( $row_count_d + 1 )) |sed -e 's/\t/ /' \
        > "$tmp_fname_f"

    # Compile the pieces into a full list--one with color codes and
    # one without:
    cat "$tmp_fname_dcolor" "$tmp_fname_f" > "$tmp_fname_display" 
    cat "$tmp_fname_d" "$tmp_fname_f" > "$tmp_fname_data"


    choice=0 # Selected item number
    col_count=2

    while (test "$choice" = "0"); do
        # Prompt the user to enter a number.
        # If the user enters 'n' or 'p', then scroll
        # to the next or previous screen.

        # -  -  -  -  -  -  - 
        # Some screen-size settings that are refreshed
        # when the screen is refreshed
        local s_rows=`stty size|cut -d ' ' -f 1`
        local s_cols=`stty size|cut -d ' ' -f 2`
        # 'display_hgt' is the number of rows to display
        # in the listing
        local display_hgt=$(( $s_rows - 2 - $hdr_hgt ))
        # 'tail_hgt' is the number of lines to select
        # before column-wrapping the displayed text.
        local tail_hgt=`echo "${display_hgt} * ${col_count}"|bc`
        local bottom_row=`echo "${screen_idx} * ${display_hgt} * ${col_count}"|bc`
        max_idx=`echo "${row_count_all}/${tail_hgt} +1"|bc`
        # -  -  -  -  -  -  - 

        # debug info
        gshc_dprint 3 "-=---=-=-=-=--=--=-= gshc_select_row()..."
        gshc_dprint 3 "input_fname=$input_fname"
        gshc_dprint 3 "row_count=$row_count_all"
        gshc_dprint 3 "nl_width=$nl_width"
        gshc_dprint 3 "s_rows=${s_rows}; s_cols=${s_cols};"
        gshc_dprint 3 "display_hgt=${display_hgt}; tail_hgt=${tail_hgt}"
        gshc_dprint 3 "bottom_row=${bottom_row}"
        gshc_dprint 3 "-=---=-=-=-=--=--=-="

        # Use head and tail to select some rows to display,
        # then use 'pr' to format it into two columns,
        col_width=$(( $s_cols / $col_count - 1 + 14 ))

        gshc_dprint 1 "col width is $col_width and scrn w = $s_cols"
        gshc_dprint 1 "chunk fname $tmp_fname_chunk"
        gshc_dprint 1 "full display file $tmp_fname_display"

        cat "$tmp_fname_display"|cut -b 1-${col_width} > /tmp/onceTEST

        if [ -f /etc/freebsd-update.conf ]  || [ -f /bsd ]; then
            # freebsd version:
            cat "$tmp_fname_display"|cut -b 1-${col_width} \
                |head -n $bottom_row \
                |tail -n $tail_hgt \
                |pr -${col_count} -a -h "" -s\| \
                 -w $s_cols  -l $display_hgt  > "$tmp_fname_chunk"
        else
            cat "$tmp_fname_display"|cut -b 1-${col_width} \
                |head -n $bottom_row \
                |tail -n $tail_hgt \
                |pr -a --header "" --columns $col_count --sep-string='|' \
                 --width=$s_cols -T -l $display_hgt  > "$tmp_fname_chunk"
        fi
###        # THIS IS A HACK: USE PR TO PROCESS THE DATA THAT HAS NO
###        # COLOR CODES, THEN EXTRACT THE TRAILING TABS AND SPACES
###        # AND PUT THEM IN THE DISPLAY VERSION BECAUSE 'PR' DOES NOT
###        # HANDLE THE COLOR CODES CORRECTLY
###        cat "$tmp_fname_data"|head -n $bottom_row \
###            |tail -n $tail_hgt \
###            |pr -a --header "" --columns $col_count --sep-string='|' \
###             --width=$s_cols -T -l $display_hgt  > /tmp/gshc_sr_hack
###        # EXTRACT THE TRAILING SPACES

        # Display the header text, but ensure that it occupies
        # no more than one line.  The ${variable_name:start_nbr:end_nbr} 
        # syntax selects a substring starting at the specified offset.
        echo ${header:0:$s_cols}

        # Display the menu that fits on one screen:
        cat "$tmp_fname_chunk"

        # Display the footer, but be sure it takes no more than one line:
        echo ${footer:0:$s_cols}
        gshc_get_txt_input "or enter a number to select an item: " 

        gshc_dprint 3 "gshc_select_row, user entered: $G_TXT"

        case "$G_TXT" in
            'n' | 'N')
                local screen_idx=$(( $screen_idx + 1 ))
                if (test $screen_idx -gt $max_idx); then
                    local screen_idx=$max_idx
                fi
                ;;
            'p' | 'P')
                local screen_idx=$(( $screen_idx - 1 ))
                if (test $screen_idx -lt 1); then
                    local screen_idx=1
                fi
                ;;
            'c' | 'C')
                gshc_get_nbr_input "Enter the number of display columns (1-6): " 6
                col_count=${G_NBR}
                ;;
            ### 'g' | 'G')
            ###     gshc_get_txt_input "Enter a new directory path: "
            ###     DIR="$G_TXT"
            ###     # recurse into the filename selection, 
            ###     # and when it returns, set the new return value
            ###     gshc_select_filename2 "$DIR"
            ###     choice=$G_NBR
            ###     ;;
            *)
                choice=`echo "$G_TXT"|tr -d "[[:alpha:][:punct:][:space:]]"`
                if (test $choice -gt $row_count_all); then
                    echo "${WARN_INVALID_NBR}"
                    choice=0
                    gshc_pause    
                fi
                ;;
        esac
    done;

    if (test "$choice" = "0"); then
        # User quit instead of selecting a value.
        # The VM_NAME varialbe will be blank.
        echo "${MSG_INVALID_SEL}"
        return 13        
    fi
    G_NBR=$choice # set global variable
    return 0
}

#------------------------------------------------------------
#------------------------------------------------------------
