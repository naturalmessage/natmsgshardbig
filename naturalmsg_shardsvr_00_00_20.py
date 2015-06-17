# -*- coding: utf-8 -*-
# naturalmsg_shardsvr_00_00_20.py
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
"""naturalmsg_shardsvr

This program will run a shard server in the Natural Message network.

A shard server can hold a small piece of a password, a small chunk of a file
(or message) or a large chunk of a file (or message).  The purpose of 
the server is to allow multiple servers to hold pieces of passwords and
files such that no one person, company, or perhaps even country, has
posession of a file.  The results is an increased degree of privacy
to a person who stores information or transfers information across
a network.

When a shard is retrieved, it is burned (delete).  A database record will
remain for a week or two to notify a client that the shard has already
been burned (or that it expired).

Any shard that is not retrieved will automatically be deleted in about
5 days or so (via an external cron job).

The operation is relatively simple:
call shard_create with a shard ID that begins with the letters SID
and contains 32 ASCII hex characters and an attached file named
shard_data.  You will receive JSON in return.

To read ashard, call shard_read?shard_id=SID..... with the 
full shard ID to read: your shard will be downloaded.

Shard server operators can choose to restrict the maximum
shard size using the conf file (typically located in
/var/natmsg/conf).  Information about the server can be
sent to naturalmessage@fastmail.fm or the current
contact info at naturalmesasge.com/contact to allow
users of the network to see your server.  That information
can contain a flag it indicate that only passwords should
be stored on your server, which means that nobody would be
allowed to store prohibited material on your server.
"""
# To do: Add check for old shards and issue a warning if the
# auto delete is not working.
#
# This is a 'big' shard server for the Natural Message network,
# which means that it is the version that saves shards (in encrypted
# format) to disk files.  The typical 'volunteer' will run this
# with a maximum shard size of between 400 and 6000000 bytes.
# You might as well use at least 4096 bytes if that is the
# size of disk sectors on your system.
#
# The shard encryption is based on a password that the server
# operator enters when the server starts (in addition to
# any client-side encryption). Once you pick a password
# for the server and save a shard, you should keep the same
# password or else clients will not be able to retrieve shards
# that you have already saved.
#
# Directions:
# ===========
# 1) Install this python program in /var/natmsg using the setup script.
#    that is intended for your exact operating system and version.  Do
#    use a setup script for a different version of the operating system
#    --there are too many pieces for that to work.
#    Pgrams in /var/natmsg, in addition to this one, include:
#     RNCryptor.py
#     shardfunc_cp_##_##_##.py (with a version nbr referenced below)
#     ssl_builtin_bob.py
#     pbkdf2_nm.py
#     nm_sign (C program from Natural Message)
#
# 2) Check all the options in the conf file. The name of the file
# is stored in the  cp_config_fname variable below, and is based on
# the version number so that you can test the next version (running
# on a different port) when the current version is running.
#
# 3) This should be run as root--there is a dropprivileges command
# that will drop it to user natmsg (unprivileged account), according
# to the numeric user id in the conf file (dropto_uid and dropto_gid
# for the group id).
#
## You need to know where the correct python3 program is -- your system
## might have two different versions installed.
## or perhaps:
#    cd /var/natmsg
#    sudo /usr/local/bin/python3 naturalmsg_shardsvr_00_00_20.py
# OR:
#    cd /var/natmsg
#    sudo /usr/local/bin/python3.4 naturalmsg_shardsvr_00_00_20.py
## OR:
#    cd /var/natmsg
#    sudo python3 naturalmsg_shardsvr_00_00_20.py
## or perhaps:
#    cd /var/natmsg
#    sudo /usr/local/bin/python3.4 naturalmsg_shardsvr_00_00_20.py
#
# 4) create a cron job that will delete old shards based on the delete
#    date in the database
#
#
###############################################################################
###############################################################################
###############################################################################
###############################################################################
test_or_prod = 'prod'
NM_VERSION_STRING = "00_00_20"  # also used in cp.id file
# The configuration (conf) file for this version of the server:
cp_config_fname = './conf/natmsg_shard_' + test_or_prod + '_' \
    + NM_VERSION_STRING + '.conf'

SHARD_ROOT = '/var/natmsg/shards'
SHARD_PW_BYTES = ''  # This is set by the user when the server starts
SERVER_FINGERPRINT = None  # This is loaded from the conf file.
shard_read_timer = False

DAY_CODES = ['a', 'b', 'c', 'd', 'e', 'f', 'g']  # For shard subdirectories


# These options will be set via the config file natmsg-shard-prod.conf
# The psql user names are in lower case.
srvr_enc_idi = ''  # gpg enc ID for mix network, set in the conf file
HOSTNAME = ''
DBNAME = ''
DB_UNAME = ''
DB_PW = ''
CONN_STR = ''
ONLINE_PUB_SIGN_KEY_FNAME = ''
ONLINE_PRV_SIGN_KEY_FNAME = ''
ONLINE_PUB_ENC_KEY_FNAME = ''
ONLINE_PRV_ENC_KEY_FNAME = ''
OFFLINE_PUB_SIGN_KEY_FNAME = ''
CRONTAB_ROOT = ''

from cherrypy.process.plugins import DropPrivileges, PIDFile
import shardfunc_cp as shardfuncs
import ssl_builtin_bob
import pbkdf2_nm

import base64
import binascii
import cherrypy
import codecs
import datetime
import hashlib
import json
import os
import psycopg2
import re
import subprocess
import sys
import time


if test_or_prod not in ('test', 'prod', 'exp'):
    """Verify that the user speciried a code for test, prod...

    The option coded above specifies one of 'test', 'prod', or
    'exp' (where 'exp' means experimental).  The options
    change the input configuration file, the output log file,
    and the PID (process ID) file.
    """

    print('Error. "test_or_prod" must be one of test, prod, exp.')
    sys.exit(12)


def fail_if_not_exist(
    """A shortcut to crash if an essential file is not ready during start."""
        fname,
        note='(no description of where the file was used)'):
    if fname is None:
        print('Error.  Filename is missing for ' + note)
        sys.exit(998)

    if not os.path.isfile(fname):
        print(
            'Error. File not found: ' + str(fname)
            + '.  It is neede for: ' + note)
        sys.exit(999)

    return(True)


def load_config():
    """Load CherryPy config options.

    Load Cherrypoy configuration options from the config flie and return
    the conf dictionary, which will go to quickstart or another cherrypy
    start routine.
    """
    global test_or_prod
    global NM_VERSION_STRING
    global SERVER_FINGERPRINT
    global HOSTNAME, DBNAME, DB_UNAME, DB_PW

    global ONLINE_PUB_SIGN_KEY_FNAME
    global ONLINE_PRV_SIGN_KEY_FNAME
    global ONLINE_PUB_ENC_KEY_FNAME
    global ONLINE_PRV_ENC_KEY_FNAME
    global OFFLINE_PUB_SIGN_KEY_FNAME

    global CONN_STR

    # The config file contains ip, port, fingerprint,
    # and a few other things:
    cherrypy.config.update(cp_config_fname)

    # Disable the option that causes the CherryPy server to restart
    # when the config file or program file is changed.
    cherrypy.config.update({'engine.autoreload.on': False})

    # Options for all or for specific web pages.
    #
    # Note: Connection keep-alive is depricated because connections
    # are kept open until Connection: close is sent by the server.
    #('Connection', 'close'),
    conf = {
        'global': {
            'request.show_tracebacks': True,
            'server.ssl_module': 'bob',
            'log.access_file': '',
            'log.screen': True,
            'tools.response_headers.on': True,
            'tools.response_headers.headers': [('Cache-Control',
            ' no-cache,no-store,max-age=0'), ('Strict-Transport-Security', '')]
        },
        '/': {
            'tools.sessions.on': False,
            'tools.staticdir.root': os.path.abspath(os.getcwd())
        },
        '/shard_create': {
            'tools.response_headers.on': True,
            'tools.response_headers.headers': [
                ('Connection', 'close'),
                ('Cache-Control', ' no-cache,no-store,max-age=0'),
                ('Strict-Transport-Security', '')]
        },
        '/shard_read': {
            'tools.response_headers.on': True,
            'tools.response_headers.headers': [
                ('Connection', 'close'),
                ('Cache-Control', ' no-cache,no-store,max-age=0'),
                ('Strict-Transport-Security', '')]
        },
        '/shard_create': {
            'tools.response_headers.on': True,
            'tools.response_headers.headers': [
                ('Connection', 'close'),
                ('Cache-Control', ' no-cache,no-store,max-age=0'),
                ('Strict-Transport-Security', '')
            ]
        },
        '/webform_admin_process': {
            'tools.response_headers.on': True,
            'tools.response_headers.headers': [
                ('Connection', 'close'),
                ('Cache-Control', ' no-cache,no-store,max-age=0'),
                ('Strict-Transport-Security', '')
            ]
        },
        '/webform_admin_inbox_read': {
            'tools.response_headers.on': True,
            'tools.response_headers.headers': [
                ('Connection', 'close'),
                ('Cache-Control', ' no-cache,no-store,max-age=0'),
                ('Strict-Transport-Security', '')
            ]
        },
        "/favicon.ico": {
            "tools.staticfile.on": True,
            "tools.staticfile.filename":
                "/var/natmsg/html/favicon.png"
        },
        '/static': {
            'tools.staticdir.on': True,
            'tools.staticdir.dir': 'static'
        },
        '/validateServer': {
            'tools.response_headers.on': True,
            'tools.response_headers.headers': [
                ('Cache-Control', ' no-cache,no-store,max-age=0'),
                ('Connection', 'keep-alive'),
                ('Content-Type', 'application/x-download')
            ]
        }
    }

    # save a PID (process ID) file:
    cp_id_fname = cherrypy.config['natmsg_root'] + os.sep \
        + 'cp_shard_' + NM_VERSION_STRING + '.pid'

    # Server pidfile (this registers the ID number of the running
    # instance as shown in 'ps -A' terminal command).
    if os.path.isfile(cp_id_fname):
        print('Error. the program ID file already exists: '
            + cp_id_fname + '.')
        print('Maybe there is another instance using this file '
            + 'or it is there from a prior crash.')
        print('If you are sure that no other instance of the program '
            + 'is running, you can delete that file and try again.')
        sys.exit(9012)

    PIDFile(cherrypy.engine, cp_id_fname).subscribe()

    if cherrypy.config['SERVER_FINGERPRINT'] is None:
        print('==========================================================')
        print('Error.  The SERVER_FINGERPRINT variable is not set.')
        print('Set this in the config file and try again.')
        print('The actual keys are generated using the nm_create_keys, '
            + 'and the nm_sign program (part of: '
            + 'https://github.com/naturalmessage/natmsgv).')
        print('The offline private key should be created on a permanently '
            + 'offline computer (the offline public key goes to your server. ')
        print('You can also contact Robert Hoot using the contact '
        'page at naturalmessage.com for direct assistance for free '
        '(for the server only).')
    else:
        SERVER_FINGERPRINT = cherrypy.config['SERVER_FINGERPRINT']
        print('The server fingerprint from the external option file '
            + 'is: ' + SERVER_FINGERPRINT)

    if cherrypy.config['server.socket_host'] == 'YOUR.SERVER.IP.ADDRESS':
        print(
            'Error. You did not set the '
            + 'server.socket_host in the config file:')
        print(cp_config_fname)
        sys.exit(4398)

    #input('press a key to continue...')
    HOSTNAME = cherrypy.config['HOSTNAME']
    DBNAME = cherrypy.config['DBNAME']
    DB_UNAME = cherrypy.config['DB_UNAME']
    DB_PW = cherrypy.config['DB_PW']

    # I want to fail now rather than to start the server with
    # missing keys..
    ONLINE_PUB_SIGN_KEY_FNAME = cherrypy.config['ONLINE_PUB_SIGN_KEY_FNAME']
    fail_if_not_exist(ONLINE_PUB_SIGN_KEY_FNAME, 'online pub sign key')

    ONLINE_PRV_SIGN_KEY_FNAME = cherrypy.config['ONLINE_PRV_SIGN_KEY_FNAME']
    fail_if_not_exist(ONLINE_PRV_SIGN_KEY_FNAME, 'online prv sign key')
    # I have to feed this file to the shardfuncs setting:
    shardfuncs.ONLINE_PRV_SIGN_KEY_FNAME = ONLINE_PRV_SIGN_KEY_FNAME

    ONLINE_PUB_ENC_KEY_FNAME = cherrypy.config['ONLINE_PUB_ENC_KEY_FNAME']
    fail_if_not_exist(ONLINE_PUB_ENC_KEY_FNAME, 'online pub enc key')

    ONLINE_PRV_ENC_KEY_FNAME = cherrypy.config['ONLINE_PRV_ENC_KEY_FNAME']
    fail_if_not_exist(ONLINE_PRV_ENC_KEY_FNAME, 'online prv enc key')

    OFFLINE_PUB_SIGN_KEY_FNAME = cherrypy.config['OFFLINE_PUB_SIGN_KEY_FNAME']
    fail_if_not_exist(OFFLINE_PUB_SIGN_KEY_FNAME, 'offline pub sign key')

    if OFFLINE_PUB_SIGN_KEY_FNAME.find('JUNKTEST') > 0:
        print('==============================================================')
        print('WARNING. You are using the temporary, testing server keys.')
        print(
            'You may continue for brief testing, '
            + 'but do not go live with these keys.')
        input('Press ENTER to continue.')

    # The crontab check should run as root.
    CRONTAB_ROOT = cherrypy.config['CRONTAB_ROOT']

    crontab_msg = '=========================================================' \
        + os.linesep \
        + 'Error.  You must schedule the housekeeping_shardsvr.py' \
        + 'file under the natmsg ID for crontab.  This program will ' \
        + 'delete old, unread shards when they expire.  You have to ' \
        + 'verify the correct path to the python3 program and to the ' \
        + 'housekeeping program, but the general format is: ' + os.linesep \
        + 'sudo -u natmsg crontab -e' + os.linesep \
        + '* 2 * * * /usr/local/bin/python3 ' \
        + '/var/natmsg/housekeeping_shardsvr.py'
    if not os.path.isfile(os.path.join(CRONTAB_ROOT, 'natmsg')):
        print(crontab_msg)
        sys.exit(983)

    try:
        fd = open(os.path.join(CRONTAB_ROOT, 'natmsg'), 'r')
        try:
            cron_dat = fd.read()
        finally:
            fd.close()
    except IOError:
        raise RuntimeError(crontab_msg)

    if cron_dat.find('housekeeping') < 0:
        raise RuntimeError(crontab_msg)

    if shardfuncs.ONLINE_PRV_SIGN_KEY_FNAME == '':
        print('shardfuncs.ONLINE_PRV_SIGN_KEY_FNAME is not set.')
        print('You must get this value from the option file and put it in')
        print('shardfuncs.ONLINE_PRV_SIGN_KEY_FNAME.')
        sys.exit(19)

    # verify that the fingerprint in the config file matches the fingerprint
    # of the offline public sign key

    with open(OFFLINE_PUB_SIGN_KEY_FNAME, 'rb') as fd:
        dat = fd.read()

    dgst = hashlib.sha384(dat)
    chk_fp = base64.b16encode(dgst.digest()).decode('utf-8').upper()
    if chk_fp != SERVER_FINGERPRINT:
        print('==========================================================')
        print('Error. The fingerprint in the config file does not match '
            + 'the SHA384 of the OFFLINE_PUB_SIGN_KEY_FNAME '
            + 'file: ' + OFFLINE_PUB_SIGN_KEY_FNAME)
        print('If you moved programs to a new machine, generate a new '
            + 'offline key for the new server.')
        sys.exit(800)

    CONN_STR = "host=" + HOSTNAME + " dbname=" + DBNAME + " user=" \
            + DB_UNAME + " password='" + DB_PW + "'"
    # pass some data to shardfuncs

    if CONN_STR == '':
        print('Error.  The database connection string is blank.')
        sys.exit(150)

    # test if the database is online
    conn, msg_d = shardfuncs.shard_connect(CONN_STR)
    if conn is None:
        try:
            print(msg_d)
        except Exception:
            print(repr(msg_d))
 
        print('Error. Could not connect to the database.  Is it Running?  '
            + 'Check \'ps -A|grep postgres\', or '
            + 'try running /root/psqlgo.sh for '
            + 'the natural message start script.')
        sys.exit(15)
    else:
        conn.close()
    #- - - - - - - - - - - - - - - - - - - -
    # This is for error messages generated by the shard server.
    #shardfuncs.LOGFILE = cherrypy.config['LOGFILE']
    shardfuncs.LOGFILE = os.path.join(cherrypy.config['natmsg_root'],
        'log_natmsg_', test_or_prod, '_', NM_VERSION_STRING, '.log')

    return(conf)


##############################################################
class StringGenerator(object):
    @cherrypy.expose
    def index(self):
        return("""<html>
            <head></head>
            <body>
            Natural Message Shard Server
            </body>
            </html>""")

    @cherrypy.expose
    def default(self, pgname):
        # The 'default' HTML files need to be in the
        # cherrypy root, which might not be /var/natmsg/html

        fd = None
        dat = None
        try:
            fd = codecs.open('html/' + pgname, 'r', 'utf8')
            try:
                dat = fd.read()
            finally:
                fd.close()
        except Exception:
            pass

        if dat is None:
            return('pgname is ' + pgname)
        else:
            return(dat)

    @cherrypy.expose
    @cherrypy.tools.json_out()
    def nm_version(self):
        global NM_VERSION_STRING

        return({'nm_version': NM_VERSION_STRING})

    @cherrypy.expose
    @cherrypy.tools.json_out()
    def nm_db_table_names(self, nonce=None):
        """
        Dump a list of tables with their definitions.  This can be used to
        confirm the version of the database tables.

        On success, this will set {'status': 'OK'} and {'results': tb_data}
        under the dictionary key of nm_db_table_names. On failure, the status
        will be set to Error.
        """
        global CONN_STR
        out = {}

        def nm_db_table_fetch(CONN_STR, out):
            """
            This performs the database call for this page generator.

            This adds keys for status and resutls to the 'out' dictionary.
            """
            conn, msg_d = shardfuncs.shard_connect(CONN_STR)
            if conn is None:
                raise RuntimeError(shardfuncs.err_log(110015, 'Failed to '
                    + 'make a database connection in '
                    + 'nm_db_table_names', extra_msg=msg_d))

            cur = conn.cursor()
            try:
                # Hi Thomas O.  Double quotes for SQL because SQL
                # uses lots of embedded single quotes.
                cmd = "SELECT *  FROM information_schema.columns " \
                    + "WHERE table_schema NOT IN " \
                    + "('information_schema', 'pg_catalog');"
                rc, my_data, msg_d = shardfuncs.shard_sql_select(cur, cmd)
                if rc != 0:
                    raise RuntimeError(
                        shardfuncs.err_log(110001, 'SQL SELECT '
                        + 'statement command failed in '
                        + 'nm_db_table_names.', extra_msg=msg_d))

                #if my_data[0][0]:  #
                if my_data and my_data[0] and isinstance(my_data[0], tuple):
                    tb_data = {}
                    recnbr = 0
                    for rec in my_data:
                        # for each row of data (contains infromation
                        # on each column in the sharddb database)
                        tb_data.update({str(recnbr): rec})
                        recnbr = recnbr + 1

                    # The database results are prepared here:
                    out.update({'status': 'OK'})
                    out.update({'results': tb_data})
                else:
                    raise RuntimeError(
                        shardfuncs.err_log(110020, 'Failed to '
                        + 'get the table structure from  '
                        + 'information_schema.'))
            except Exception as my_exc:
                cur.close()
                conn.close()
                raise RuntimeError(
                    shardfuncs.err_log(1121, 'Failure fetching '
                    + 'database data for '
                    + 'nm_db_table_names.')) from my_exc

            return(out)

        # ./././././././.../..../.../././././././.
        # The main part of this page generator:
        try:
            if nonce:
                sig_dict_tmp = shardfuncs.sign_nonce(nonce=nonce)
                if sig_dict_tmp is None:
                    raise RuntimeError(
                        '110010: The signature did not work. '
                        'The sign_nonce() method returned')

                # This gets {'signature_b64': Base64OfTheNonce}
                out.update(sig_dict_tmp['sign_nonce'])

            out = nm_db_table_fetch(CONN_STR, out)
        except Exception:
            return(shardfuncs.nm_err_dict('nm_db_table_names'))

        return({'nm_db_table_names': out})

    ############################################################
    ############################################################
    @cherrypy.expose
    @cherrypy.tools.json_out()
    def server_local_settings(self, public_recipient=None, shard_metadata=None,
        nonce=None, debug=False):
        """
        This will return a list of settings used for the live server.
        Note ready yet.
        """
        # These should come from settings in an option file
        global NM_VERSION_STRING

        out = {}

        try:
            if nonce:
                sig_dict_tmp = shardfuncs.sign_nonce(nonce=nonce)
                if sig_dict_tmp is None:
                    raise RuntimeError('110010: The signature did not work. '
                        + 'The sign_nonce() method returned')

                # This gets {'signature_b64': Base64OfTheNonce}
                out.update(sig_dict_tmp['sign_nonce'])
        except Exception:
            return(shardfuncs.nm_err_dict('server_local_settings'))

        out.update({'version': NM_VERSION_STRING})
        return({'server_local_settings': out})
    ############################################################
    ############################################################

    @cherrypy.tools.json_out()
    @cherrypy.expose
    def validateServer(self, nonce=None, debug=False):
        """
        This will accept a small file (a nonce) that the server
        will sign with its online private key and return
        a detached signature file.

        The client can verify the server using this process:
        1) Using the result of this requist, as the 'signature'
           of the original nonce.
        2) Grab the 'signature of the online key by the offline key'
           for the server in question and confirm that signature.
           That info is available in the serverFarmTest web page on
           the main Natural Message server.
        3) Confirm that the fingerprint in the server config file
           matches the SHA384 of the offline public key.
        Note that the main Natural Message operator will check
        for any changes in the online key that are inconsistent
        with historical data.
        """

        # Function:
        # 1) read a 'shard' that contains the nonce (maybe allow only tiny
        #    file sizes).
        # 2) Run a python subprocess to call the C program
        #    to sign the nonce (I am calling a C program because I
        #    did not find a good python library for libgcrypt by itself
        #    and there was a conflict between version of libgcrypt
        #    capabilities for 1.5 and 1.6).
        global CONN_STR

        out = {}
        dbg = False
        sig_b64_dict = None
        sig_dict_tmp = None

        try:
            # Python seems to get the data type right, but
            # this might be safer than making assumptions.
            if isinstance(debug, str):
                if debug.lower() in ('true', 't'):
                    dbg = True
            elif isinstance(debug, bool):
                if debug:
                    dbg = True

            if nonce is not None:
                sig_dict_tmp = shardfuncs.sign_nonce(nonce=nonce)
                if sig_dict_tmp is None:
                    raise RuntimeError(
                        '110010: The signature did not work. '
                        + 'The sign_nonce() method returned')

                # This gets {'signature_b64': Base64OfTheNonce}
                out.update(sig_dict_tmp['sign_nonce'])

            else:
                raise RuntimeError(
                    '120120: There was no nonce passed to validateServer. '
                    + 'You need to upload a file called "nonce".')
        except Exception:
            return(shardfuncs.nm_err_dict('serverValidate'))

        # final return
        return({'serverValidate': out})

    ############################################################
    ############################################################
    ############################################################
    ############################################################
    ############################################################
    ############################################################
    ############################################################
    ############################################################
    ############################################################
    ############################################################
    @cherrypy.expose
    @cherrypy.tools.json_out()
    def shard_create(self, shard_id=None, shard_data=None,
        nonce=None, payment_key=None, nm_pow=None, debug=False):
        """This will accept an attached filed named shard_data
        that contains base64 data.  If you upload binary crap,
        it will be rejected.
        """
        # THIS WILL CONTAIN SHARD ENCRYPTION AND WILL EVENTUALLY HANDLE
        # ALL SHARDS FOR THE SERVER.
        # IT WILL HAVE ONE SIZE LIMIT FOR THE SERVER
        # WHICH CAN BE SET IN THE CONF FILE.
        global SHARD_PW_BYTES
        global DAY_CODES
        global CONN_STR

        out = {}
        dbg = False
        msg_d = None

        #././././././././././././././././././././././././././././././././././
        def db_write(CONN_STR, shard_id, shard_data, dbg, out):
            # This verifies that the shard ID is in a good format.
            # The random part of the IDs are validated by validate_id_chars(),
            # which restricts it to HEX, _ and -.
            # The character set also avoid directory traversal
            # attacks for shards
            # that are stored on disk (e.g., ID name of '/etc/passwd').
            global DAY_CODES
            global SHARD_ROOT

            rc, msg_d = shardfuncs.verify_id_format(
                shard_id, expected_prefix='SID')

            if(rc != 0):
                raise RuntimeError(
                    '9000: The format of the shard ID was bad: ')

            #------------------------------------------------------------
            # set up database connection
            conn, msg_d = shardfuncs.shard_connect(CONN_STR)
            if conn is None:
                raise RuntimeError('9010: Connection to database failed ')

            cur = conn.cursor()

            #------------------------------------------------------------
            # Reject the request if the record already exists.
            # This protects against a "Server Rewrite Attack" through
            # which a corrupt directory server could simply read the
            # messages and recreate the shards under the same name so
            # that nobody would ever know.  This implies that the datbase
            # record is retained a bit beyond the normal maximum potential
            # lifespan of the shard.  The best protection against the rewrite
            # attack would be either the shared secret to encrypt the metadata
            # with a key that the server can never get, or use out of band
            # communication (across a different network).
            # Right now, I have to check two sources, but eventually there will
            # be one shard table.
            cmd = "SELECT shardsvr.shard_id_exists('%s');" % (shard_id)
            rc, my_data, msg_d = shardfuncs.shard_sql_select(cur, cmd)
            if rc != 0:
                cur.close()
                conn.close()
                rc = 9100
                msg = 'SQL SELECT statement command failed in shard_create ' \
                    + 'when checking shard ID existence.'
                shardfuncs.log_err(rc, msg_d)
                raise RuntimeError(str(rc) + ': ' + msg)

            if my_data[0][0]:
                # The return record is not None.
                # Reject a request to overwrite a shard that
                # existed recently (even if the shard data has been deleted).
                cur.close()
                conn.close()
                raise RuntimeError(
                    '9200: Shard ID existed recently.  '
                    + 'You can not overwrite shards.')

            # Test if the file was uploaded
            if shard_data is None:
                cur.close()
                conn.close()
                raise RuntimeError(
                    '9900: No file was uploaded.  '
                    + 'You must upload a file with the '
                    + 'post parameter name "shard_data".')
            else:
                # send data from shard_data to output.
                # MODIFY THIS TO GET A BLOCK AT A TIME AND STOP IF
                # THE FILE IS TOO BIG.
                f_in = None
                try:
                    f_in = shard_data.file
                except Exception:
                    raise RuntimeErro(
                        '9300: Could not read the shard data from network '
                        + 'package.  Try naming the file \'shard_data\' '
                        + 'and try again.')

                try:
                    dat = f_in.read()  # This produces a python bytes() object.
                except Exception:
                    f_in.close()
                    raise RuntimeError(
                        '9323: could not read the uploaded shard')

                f_in.close()

                # random day count between about 20 and 40
                del_day_count = int(
                    (int.from_bytes(os.urandom(1), byteorder='little'))
                    / 256.0 * 20) + 20

                today = datetime.date.today()
                day_code = DAY_CODES[today.weekday()]
                shard_path = os.path.join(SHARD_ROOT, day_code)
                shard_fname = os.path.join(shard_path,  shard_id)
                exp_date = datetime.date.today() + datetime.timedelta(days=6)
                del_date = datetime.date.today() \
                    + datetime.timedelta(days=del_day_count)

                if cherrypy.config['shard_encrypt_version'] == 1:
                    # dat will now be bytes
                    cryptor = shardfuncs.RNCrypt_zero()
                    encrypted_data = cryptor.encrypt(dat, SHARD_PW_BYTES)
                elif cherrypy.config['shard_encrypt_version'] == 0:
                    # Now that dat is bytes, unecrypted will
                    # probably cause an error,
                    # but we shold not be using this anyway.
                    encrypted_data = dat
                else:
                    raise RuntimeError(
                        '9500: The requested encryption format for '
                        + 'shards was not expected: '
                        + repr(cherrypy.config['shard_encrypt_version']))

                f = None
                try:
                    f = open(shard_fname, 'wb')
                    try:
                        if isinstance(encrypted_data, bytes):
                            # writing binary
                            f.write(encrypted_data)
                        else:
                            f.write(bytes(encrypted_data, 'utf-8'))
                    finally:
                        if f.fileno():
                            os.fsync(f.fileno())
                        f.close()
                except IOError:
                    raise RuntimeError(
                        '9600: Failed to write the shard file.')

                # The sql command wants the date in a an odd format,
                # so do it here. PostgreSQL wants the date like this,
                # including the quotes: '2014-09-29'::date
                expire_dt_sql = "'" + str(exp_date.year) + "-" \
                    + str(exp_date.month).zfill(2) + "-" \
                    + str(exp_date.day).zfill(2) + "'::date "

                del_dt_sql = "'" + str(del_date.year) + "-" \
                    + str(del_date.month).zfill(2) + "-" \
                    + str(del_date.day).zfill(2) + "'::date "

                # Note that the code here does not need
                # to add quotes around the date values.
                cmd = "INSERT INTO shardsvr.big_shards(" \
                    + "  big_shard_id, " \
                    + "  delete_db_entry_on_date, " \
                    + "  expire_on_date, " \
                    + "  encryption_format, " \
                    + "  day_code) " \
                    + "values('%s', %s, %s, %d, '%s');" % ( shard_id, del_dt_sql, expire_dt_sql, cherrypy.config['shard_encrypt_version'], day_code)

                rc, msg_d = shardfuncs.shard_sql_insert(cur, cmd)
                if rc != 0:
                    cur.close()
                    conn.close()
                    shardfuncs.log_err(9700, msg_d)
                    raise RuntimeError('9700: SQL insert command failed '
                        + 'in shard_create.')
                else:
                    cur.execute('commit;')
                    cur.close()
                    conn.close()
                    out.update({'status': "OK"})

            return(out)

        #- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
        def process_args(debug, nonce, shard_id, out):
            # Python seems to get the data type right, but
            # this might be safter than making assumptions.
            dbg = False

            if isinstance(debug, str):
                if debug.lower() in ('true', 't'):
                    dbg = True
            elif isinstance(debug, bool):
                if debug:
                    dbg = True

            if nonce:
                sig_dict_tmp = shardfuncs.sign_nonce(nonce=nonce)
                if sig_dict_tmp is None:
                    raise RuntimeError('110010: The signature did not work. '
                        + 'The sign_nonce() method returned')

                # This gets {'signature_b64': Base64OfTheNonce}
                out.update(sig_dict_tmp['sign_nonce'])

            if (shardfuncs.ALLOW_NEW_MSGS is False):
                # The flag in
                # /opt/python3/lib/python3.4/site-packages/shardfuncs.py
                # (or wherever it is in the sys.path path),
                # has been unset. Do not allow new messages to be created,
                # but allow old ones to be read
                raise RuntimeError(
                    '8700: The main server responded, but is not '
                    + 'accepting new messages.')

            if dbg:
                if shard_data is not None:
                    shardfuncs.json_keyval(
                        {'DEBUG0010': 'I HAVE THE SHARD DATA.'})
                    shardfuncs.json_keyval(
                        {'DEBUG0020': 'Here it is ' + repr(shard_data)})

            # see if the user passed a shard_id,
            # if so verify its format
            if shard_id is None:
                raise RuntimeError('8900" The shard_id is missing '
                    + 'from shard_create.')

            return((dbg, out))
        #././././././.././././././././././././././././././././././././././././
        #         main processing for this page generator starts here
        #
        try:
            dbg, out = process_args(debug, nonce, shard_id, out)
            out = db_write(CONN_STR, shard_id, shard_data, dbg, out)
        except Exception as my_exc:
            return(shardfuncs.nm_err_dict('shard_create'))

            #././././././././././././././././././././././././././././././././

        # final return
        return({'shard_create': out})

    ############################################################
    ############################################################
    ############################################################
    ############################################################
    ############################################################
    ############################################################
    ############################################################
    ############################################################
    ############################################################
    ############################################################
    @cherrypy.expose
    def shard_read(self, debug=False, shard_id=None, nonce=None):
        """shard_read: read and return the contents of a big
        shard that might be up to (1024^2) * 5 = 5242880 bytes.
        This will return whatever was sent, put into base64
        inside the returned JSON.

        To get the original content on the client side,
        pull shard_data from the JSON and un-base64 it.

        I should clone this and make another version that
        just spits back the file as a download.

        It does not make sense to ask for the signed nonce
        in here because I return just the data -- I would
        have to switch to a multipart or the user should
        make a separate call to validate the server.
        """
        ### WARNING. IF YOU UPDATE THIS ROUTINE
        ### CHECK IF THE SERVERVALIDATION() METHOD
        ### NEEDS THE SAME CHANGES.
        global SHARD_PW_BYTES
        global CONN_STR

        big_data = None
        out = {}
        dbg = False

        def _process_args(debug, nonce, shard_id, out):
            # Python seems to get the data type right, but
            # this might be safter than making assumptions.
            dbg = False

            if isinstance(debug, str):
                if debug.lower() in ('true', 't'):
                    dbg = True
            elif isinstance(debug, bool):
                if debug:
                    dbg = True

            if nonce:
                sig_dict_tmp = shardfuncs.sign_nonce(nonce=nonce)
                if sig_dict_tmp is None:
                    raise RuntimeError(
                        '110010: The signature did not work. '
                        + 'The sign_nonce() method returned')

                # This gets {'signature_b64': Base64OfTheNonce}
                out.update(sig_dict_tmp['sign_nonce'])

            if dbg:
                if shard_data is not None:
                    shardfuncs.json_keyval(
                        {'DEBUG0010': 'I HAVE THE SHARD DATA.'})
                    shardfuncs.json_keyval(
                        {'DEBUG0020': 'Here it is ' + repr(shard_data)})

            return((dbg, out))

        def _check_shard_status(CONN_STR, shard_id, conn, cur):
            cmd = str("SELECT burned, expired, delete_db_entry_on_date, "
                + "encryption_format, day_code "
                + "FROM shardsvr.big_shards "
                + "WHERE  big_shard_id = '%s';" % (shard_id))

            my_data = None
            rc, my_data, msg_d = shardfuncs.shard_sql_select(cur, cmd)
            if rc != 0:
                cur.close()
                conn.close()
                raise RuntimeError(
                    '6700: SQL SELECT statement command failed in shard_read.')

            if my_data is None:
                cur.close()
                conn.close()
                raise RuntimeError('6800: SQL fetch of the shard data failed.')

            if len(my_data) > 0:
                # The "[0][0]" array notation here selects the first data row
                # (row #0) and the first col (col #0), and the next one
                # gets data from the second column (col # 1).
                brn = my_data[0][0]
                exp = my_data[0][1]
                del_date = my_data[0][2]
                encryption_format = my_data[0][3]
                day_code = my_data[0][4]

                return({
                        'brn': brn, 'exp': exp, 'del_date': del_date,
                        'encryption_format': encryption_format,
                        'day_code': day_code
                    })
            else:
                # The shard was not found
                return(None)

        def _fetch_shard_data(shard_path, shard_id, status, conn, cur):
            # RNCrypt_zero is a modified RNCryptor with no pbkdf2 iterations.
            cryptor = shardfuncs.RNCrypt_zero()
            try:
                f = open(shard_path + '/' + shard_id, 'rb')
                try:
                    dat_in = f.read()
                finally:
                    f.close()
            except IOError:
                cur.close()
                conn.close()
                raise RuntimeError(
                    '6900: Could not open the shard for reading.')


            if status['encryption_format'] == 1:
                # Read the data and decrypt using the
                # method that was coded in the database
                # for this shard.  This would theoretically
                # Allow me to change the encryption method
                # on a live server -- code newly created
                # shards with the new algo, and the olds ones
                # will be processed with the old one, until
                # the old ones are all gone in 5 or so days.

                try:
                    # The regular RNCryptor (in early 2015) expected str output
                    # so use Bob's override version here.
                    # This now returns bytes().
                    big_data = cryptor.decrypt(dat_in, SHARD_PW_BYTES)
                except Exception:
                    cur.close()
                    conn.close()
                    raise RuntimeError(
                        '7001: Error decrypting the shard file.  The '
                        + 'umodified RNCryptor routine seems to expect '
                        + 'UTF-8, but I use a modified post_decrypt '
                        + 'routine to avoid this error.  If you see this '
                        + 'error, it could mean that you need to restore '
                        + 'my RNCryptor class redefinition.')

            elif status['encryption_format'] == 0:
                # We always use encryption, so this line should not run
                big_data = dat_in
            else:
                cur.close()
                conn.close()
                raise RuntimeError(
                    '7100: Unknown encryption format returned for this shard.')

            dat_in = None

            if (big_data is None):
                cur.close()
                conn.close()
                raise RuntimeError('7200: OOPS. I do not have the big data')
            else:
                # RETURN THE DATA xxx
                return(big_data)

        # -  -- - - - -
        def _burn_shard(shard_id, status, conn, cur):
            """
            The shard has already been read, so set the burn flag.

            Don't worry about setting the expire flag--that is done
            elsewhere, and I always check the data anyway.
            """
            # The burn process is done in two steps:
            #  1) run the shard_burn(shard_id) stored procedure,
            #  2) erase the shard from disk.
            smd_data = None
            # Burn the shard using the shard_delete stored procedure:
            cmd = "SELECT * FROM shardsvr.shard_burn('%s');" % (shard_id)
            rc, smd_data, msg_d = shardfuncs.shard_sql_select(cur, cmd)

            if smd_data is None:
                shardfuncs.log_err(7500,  repr(msg_d))
                cur.close()
                conn.close()
                raise RuntimeError('7500: SQL burn command failed.')

            if smd_data[0] == 0:
                cur.close()
                conn.close()
                shardfuncs.log_err(
                    7600,
                    'SQL burn command returned zero rows.')
                raise RuntimeError(
                    '7600: SQL delete/burn statement command returned '
                    + '0 rows.  Transaction was rolled back.')

            # Erase the "big" shard file from disk
            if status['day_code'] == ' ':
                shard_path = SHARD_ROOT
            else:
                shard_path = os.path.join(SHARD_ROOT, status['day_code'])

            os.remove(shard_path + os.path.sep + shard_id)
            return(True)

            # -  -- - - - -
        def _get_shard(CONN_STR, shard_id, out):
            global SHARD_ROOT

            conn, msg_d = shardfuncs.shard_connect(CONN_STR)
            if conn is None:
                raise RuntimeError(
                    '983845: Could not make database connection in '
                    + 'shard_read.')

            cur = conn.cursor()

            status = _check_shard_status(CONN_STR, shard_id, conn, cur)
            if status is None:
                # The shard was not found.  I can not get it
                raise RuntimeError('983855: Shard was not found (not '
                    + 'burned, not expired, just not found.')

            if status['day_code'] not in ('a', 'b', 'c', 'd', 'e', 'f', 'g'):
                raise RuntimeError(
                    'Failed to get a valid day code for shard storage: '
                    + str(shard_id))
            else:
                shard_path = os.path.join(SHARD_ROOT,  status['day_code'])

            if not status['brn'] and not status['exp']:
                if datetime.date.today() > status['del_date']:
                    raise RuntimeError(
                        '837374: The shard has already expired.')
                else:
                    big_data = fetch_shard_data(
                        shard_path, shard_id, status, conn, cur)
            else:
                if status['brn']:
                    raise RuntimeError('837374: The shard has already burned.')
                elif status['exp']:
                    raise RuntimeError(
                        '837375: The shard has already expired.')
                else:
                    raise RuntimeError(
                        '837376: The shard was not available '
                        + '(unknown reason).')

            return((big_data, status, conn, cur, out))
        #./././././...//.././././././.././.././.././.././.../.../././
        #           This is the main part of this page generator
        #
        try:
            dbg, out = _process_args(debug, nonce, shard_id, out)
            big_data, status, conn, cur, out = _get_shard(
                CONN_STR, shard_id, out)
            _burn_shard(shard_id, status, conn, cur)  # failures here are bad!

            # RETURN THE DATA in binary format -- set headers first.
            # RETURN THE DATA in binary format -- set headers first.
            # RETURN THE DATA in binary format -- set headers first.
            cherrypy.response.headers['Content-Type'] = \
                'application/x-download'
            if not isinstance(big_data, bytes):
                big_data = bytes(big_data, 'utf-8')
        except Exception:
            return(shardfuncs.nm_err_dict('shard_read', out=out))

        return(big_data)
        # - - - -
        #./././././...//.././././././.././.././.././.././.../.../././

    ############################################################
    ############################################################
    ############################################################
    @cherrypy.expose
    @cherrypy.tools.json_out()
    def remix_packet(self, debug=False, shard_data=None,
        nonce=None,
        payment_key=None):
        """remix_packet: UNDER CONSTRUCTION, NOT FINISHED.
        THIS MIGHT NOT BE READY UNTIL AFTER THE INITIAL
        RELEASE.
        This will accept a shard_remix packet
        that is encrypted in GPG, then read the JSON in that
        and process all the 'actions.'  The sender can
        inlude a key_name that will hold the status of
        another key--the sender can read the status shard
        via a remix_read to learn the creation status, but
        not the read status.
        """
        # UNDER CONSTRUCTION
        # UNDER CONSTRUCTION
        # UNDER CONSTRUCTION
        # UNDER CONSTRUCTION
        # UNDER CONSTRUCTION
        # UNDER CONSTRUCTION
        # remix logic:
        # 1) receive packet.
        # 2) verify format.
        # 3) decrypt using private key.
        # 4) check for json and string 'remix'
        # 5) scan each 'action' --there might be multiple actions, each
        #    with its own shard_data.
        #   a) if there is a delay for this action,
        #      (in minutes that I round +- 30 sec)
        #      save the JSON to a file, generate a key if there isn't one
        #      in the JSON, send the time and the key to the
        #      remix_pending database.
        #   b) if action is 'forward,' extract the
        #      embedded attachement and send it
        #      to the next server via remix_packet()
        #   c) if the action is 'save', save the shard.
        ## I SHOULD REFACTOR THIS AGAIN TO USE THE SAME CORE
        ## AS shard_read    WITH OPTIONS FOR THE JSON FUNCTION NAME,
        ## and INPUT ROUTINE.
        #
        out = {}
        dbg = False

        # Python seems to get the data type right, but
        # this might be safter than making assumptions.
        if isinstance(debug, str):
            if debug.lower() in ('true', 't'):
                dbg = True
        elif isinstance(debug, bool):
            if debug:
                dbg = True

        if nonce is not None:
            sig_dict_tmp = shardfuncs.sign_nonce(nonce)
            try:
                sig_b64_dict = sig_dict_tmp['sign_nonce']
            except KeyError:
                rc = 7740
                msg = 'The signature did not work. ' \
                    + 'The sign_nonce() method returned' \
                    + json.dumps(sig_dict_tmp)
                out.update(shardfuncs.log_err(rc, msg))
                return({'validateServer': out})

            out.update(sig_b64_dict)

        if dbg:
            if shard_data is not None:
                shardfuncs.json_keyval({'DEBUG0010': 'I HAVE THE SHARD DATA.'})
                shardfuncs.json_keyval(
                    {'DEBUG0020': 'Here it is ' + repr(shard_data)})

        cont_len = 0
        is_chunked = False
        is_multipart = False

        for k, v in cherrypy.request.headers.items():
            if k.lower() == 'content-length':
                is_chunked = False
                cont_len = int(v)
            elif k.lower() == 'transfer-encoding' and 'chunked' in v.lower():
                is_chunked = True

            if k.lower() == 'content-type' and 'multipart' in v.lower():
                is_multipart = True

        mix_id = re.sub(r'[=]*', '', 'MIX'
                + bytes.decode(binascii.b2a_hex(os.urandom(16))).upper()[0:32])
        rc, msg_d = shardfuncs.verify_id_format(mix_id, expected_prefix='MIX')

        if(rc != 0):
            out.update({'Error': 'The format of the mix ID was bad: '})
            out.update({'Error-detail': msg_d['Error']})
            if mix_id is not None:
                out.update(
                    {'DEBUG0100': 'the mix ID was %s.' % (repr(mix_id))})
            return({'remix_packet': out})

        # Test if the file was uploaded
        if shard_data is not None:
            # save the shard data to a shard data file that has
            # a 'mix id' as a file name:
            # MODIFY THIS TO GET A BLOCK AT A TIME AND STOP IF
            # THE FILE IS TOO BIG.
            try:
                f_in = shard_data.file
                f = open('/var/natmsg/shards/' + mix_id, 'w')
                try:
                    f.write(f_in.read().decode('utf8'))
                finally:
                    if f.fileno():
                        # sync to disk to be sure it is there
                        os.fsync(f.fileno())

                    f.close()
                    f_in.close()
            except IOError:
                return({'remix_packet': {'status': 'Error', 'Error': 'Could not write shard'})

        conn, msg_d = shardfuncs.shard_connect(CONN_STR)
        if conn is None:
            return({'remix_packet': msg_d})

            cur = conn.cursor()

            # Random day count between about 20 and 40
            del_day_count = int(
                    (int.from_bytes(os.urandom(1), byteorder='little'))
                    / 256.0 * 20) + 20

            today = datetime.date.today()
            exp_date = datetime.date.today() + datetime.timedelta(days=6)
            del_date = \
                datetime.date.today() + datetime.timedelta(days=del_day_count)

            # The sql command wants the date in a an odd format, so do it here.
            # PostgreSQL wants the date like this, including the quotes:
            #   '2014-09-29'::date
            expire_dt_sql = "'" + str(exp_date.year) + "-" \
                + str(exp_date.month).zfill(2) + "-" \
                + str(exp_date.day).zfill(2) + "'::date "

            del_dt_sql = "'" + str(del_date.year) + "-" \
                + str(del_date.month).zfill(2) + "-" \
                + str(del_date.day).zfill(2) + "'::date "

            # Note that the code here does not need to add
            # quotes around the date values.
            cmd = "INSERT INTO shardsvr.big_shards(" \
            + "  big_shard_id, " \
            + "  delete_db_entry_on_date, " \
            + "  expire_on_date) " \
            + "values('%s', %s, %s)" \
            + ";" % (
                mix_id,
                del_dt_sql,
                expire_dt_sql)

            rc, msg_d = shardfuncs.shard_sql_insert(cur, cmd)
            if rc != 0:
                out.update(
                    {'Error': 'SQL insert command failed in remix_packet.'})
                out.update({'Error-detail': msg_d['Error']})
                cur.close()
                conn.close()
                return({'remix_packet': out})
            else:
                cur.execute('commit;')
                cur.close()
                conn.close()
                out.update({'status': "OK"})

            cur.close()
            conn.close()

        else:
            out.update(
                    {'Error': 'No file was attached to the remix packet.  '
                    + 'You must upload a file with the post parameter '
                    + 'name "shard_data".'})
            return({'remix_packet': out})

        # Remix packet was received and saved in the shards directory.
        # Now decrypt it.

        # final return
        return({'remix_packet': out})


    ############################################################
    ############################################################
    ############################################################
    # - - - - - - - - - - - - - - - - - - - -
    # - - - - - - - - - - - - - - - - - - - -
    #def ToDo_WebForm_Questions(self)
    # - - - - - - - - - - - - - - - - - - - -
    # - - - - - - - - - - - - - - - - - - - -


if __name__ == '__main__':
    # The next part will prompt the user to enter
    # a password that will hashed with PBKDF2, then
    # the resulting hash will be used to encrypt
    # the shards (and maybe smd data?). Encryption
    # in memory might make it easier for people to
    # run local shard or directory servers on a VPS
    # that does not have easy access to encrypted disk,
    # plus this version makes it harder for a generic
    # virus to see the real data.
    SHARD_PW_BYTES = pbkdf2_nm.pw_hash(
            iterations=97831,
            verify_fname='/var/natmsg/shard_server_receipt.save')
    if SHARD_PW_BYTES is None:
        print('The shard password is bad.  Quitting now.')
        sys.exit(12)

    # try loading config now AND in the loop below.  I need some
    # settings for the custom ssl thing.
    load_config()

    # I will now load a cusomized version of
    # /usr/local/lib/python3.4/site-packages/cherrypy/wsgiserver/ssl_builtin.py
    # to make my own ssl-adapter because the default one is
    # hard-coded to accept SSLv3 or higher, and I don't want SSL v3.
    my_ssl_adapter = ssl_builtin_bob.BuiltinSSLAdapter(
        cherrypy.config['server.ssl_certificate'],
        cherrypy.config['server.ssl_private_key'])

    cherrypy.wsgiserver.wsgiserver3.ssl_adapters.update(
        {"bob": "ssl_builtin_bob.BuiltinSSLAdapter"})

    # The user needs to call this with root privileges,
    # then the following command drops to the natmsg user ID.
    DropPrivileges(cherrypy.engine, gid=cherrypy.config['dropto_gid'],
        uid=cherrypy.config['dropto_uid']).subscribe()

    # After dropping to natmsg user id, see if I can
    # write to the shard directory:
    tst_fname = os.path.join(SHARD_ROOT, 'a', 'junktest.txt')
    try:
        fd = open(tst_fname, 'w')
        try:
            fd.write("This is a file to be sure that "
                + "I can write to this directory")
        finally:
            fd.close()
    except IOError:
        print('Error. Could not write a test file to the shards directory:'
            + tst_fname)
        sys.exit(34)

    webapp = StringGenerator()
    ####webapp.generator = StringGeneratorWebService()
    ##cherrypy.quickstart(webapp, '/', conf)

    # The following loop allows the server to restart and to
    # reload config options if it should fail for some reason.
    while True:
        # if the server dies, you can restart it without having to re-enter the
        # Natural Message shard server password (because the password has
        # already been processes).
        print('+++++++ Top of the main loop')
        cherrypy.server.httpserver = None
        conf = load_config()
        ###cherrypy.tree.mount(StringGenerator(), "/", config)

        cherrypy.tree.mount(StringGenerator(), "/", conf)
        cherrypy.engine.signals.subscribe()
        cherrypy.engine.start()
        cherrypy.engine.block()  # run until the sever dies
        print('=======**** The server should be running. You should not see '
            'this line until after the server is reset.')
        time.sleep(3)  # leave this here to make it easier to quit the loop
