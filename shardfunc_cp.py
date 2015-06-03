#shardfunc_cp_0_0_21.py

# to do: disable ID verification for the one-time burn test,

################################################################################
# Copyright 2015 Natural Message, LLC.
# Author: Robert Hoot (naturalmessage@fastmail.fm)
#
# This file is part of the Natural Message Shard Server.
#
# The Natural Message Shard Server is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Natural Message Shard Server is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Natural Message Shard Server.  If not, see <http://www.gnu.org/licenses/>.
################################################################################
SECRET_SAUCE_INT = [0x00, 0x00]

# The calling server will set this value from an option:
ONLINE_PRV_SIGN_KEY_FNAME = ''


# We use a fake email destination ID to keep the shard_metadata
# table happy and so that Chris can reuse his code that creates
# Natural Messages in the full client.
RESERVED_EMAIL_DEST_ID = 'PUB004001010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000019999'
import RNCryptor
import hmac # for KDF
import hashlib # for KDF
from Crypto.Protocol import KDF

import base64
import codecs
import collections
import datetime
import hashlib
import os
import psycopg2
import re
import subprocess
import sys
import traceback

#import io
#import xml.etree.ElementTree as ET

ALLOW_NEW_MSGS = True # set to false to disallow new shards or smd
ERR_LOG_TO_FILE = True #used by err_log. THIS SHOULD BE SET IN THE GLOBAL OPTIONS FILE THAT IS LOADED BY CHERRYPY AT STARTUP
LOGFILE = 'SET_LOG_FILE_NAME_FROM_THE_MAIN_PROGRAM_AND_INCLUDE_THE_VERSION_NBR'
NATMSG_ROOT = 'SET_ROOT_DIR_FROM_THE_MAIN_PROGRAM'


# IT IS AN ERROR TO LEAVE THIS json_blocks_printed here
# BECAUSE THE COUNT IS HELD ACROSS THREADS
json_blocks_printed = 0

CURRENT_YYYYMMDD = int(datetime.datetime.now().strftime("%Y%m%d"))
# allow an account created on oct 1 to extedn to jan 31 a year and 3 mths 
#   >>> datetime.datetime(2015, 10, 1)  + + datetime.timedelta(488,0,0)
#   datetime.datetime(2017, 1, 31, 0, 0)
d_tmp = datetime.datetime.now() + datetime.timedelta(489,0,0) 
ID_CUTOFF_YYYYMMDD = int(d_tmp.strftime("%Y%m%d"))
d_tmp = None

################################################################################
def safe_string(s, max_len=2000):
	"""
	This will try to return the str() of the object, but if that
	fails, it will return the repr().  I will use this when creating
	error messages that might contain non-utf-8 from user input
	or other errors.
	"""

	r = None
	if isinstance(s, dict):
		try:
			r = json.dumps(s, sort_keys=True, indent=True)
		except:
			pass
	elif isinstance(s, list):
		tmp_r = []
		for q in s:
			tmp_r.append(safe_string(q))	

		r = ', '.join(tmp_r)


	if r is None:
		try:
			r = str(s)
		except:
			r = repr(s)

	if len(r) > max_len:
		r = r[0:max_len]

	return(r)

################################################################################
def try_it(mod_name, func_name,  err_nbr, err_msg, args=None, arg_dict=None, simulate_err_nbr=None):
	"""
	This will run a function, the name of which will
	be passed as a string, and trap errors so that I can format the 
	error message and let the error handler above this print the message.
	This routine is most useful for the web server that needs to
	format crash info into JSON format.
	
	For functions defined in the current module with global scope,
	set 'mod_name' to None.

	args is a list of positional arguments.

	The arg_dict is a Python dictionary object (name all your 
	arguments!), or you can set it to None.

	err_nbr and err_msg are things that you want the error message to
	say in the event that the call fails.  You should always pass
	err_nbr and err_msg.  It is an art to determine how much
	additional state information to pas as the error_message.
  This function will also show Python error information and traceback.

	simulate_err_nbr is for testing purposes: set it to an err_nbr value
	that might be called in your program, and if this function 
	detects that a call has been made with that err_nbr, it will
	force an error.  Use this to test the client or to test
	the validity of error traps that might have run-time errors
	while trying to print pretty error messages.
	"""
	rc = None

	if mod_name:
		# The function is defined in an external module.
		f = getattr(sys.modules[mod_name], func_name)
	else:
		# The function is defined in this file.
		# Note that locals() would refer to things defined within this
		# function, but that it not the case.
		f = globals()[func_name]

	# I might have gotten a data value instead of a function, the 
	# you would get if you "called" os.name. The following tests
	# if f is callable (if it is a function):
	if not isinstance(f, collections.Callable):
		return(f)
	

	if arg_dict and not isinstance(arg_dict, dict):
		print('Error.  The argument list sent to try_it was not a Python ' \
			+ 'dictionary object.')
		print('Reference: ' + str(err_nbr))
		raise RuntimeError('Bad function definition in try_it')
		
	if err_nbr is None:
		print('Error.  The was no err_nbr sent to try_it')
		raise RuntimeError('Bad call to try_it()')
		
	if err_msg is None:
		print('Error.  The was no err_msg sent to try_it')
		raise RuntimeError('Bad call to try_it()')

	try:
		if arg_dict:
			# If the args are not set to None:
			rc = f(*arg_dict)
		else:
			if args:
				rc = f(*args)
			else:
				rc = f()

		if simulate_err_nbr and err_nbr == simulate_err_nbr:
			# Force an error for testing purposes
			raise RuntimeError('Simulated error for testing purposes. Reference ' \
				+ str(err_nbr))

	except:
		python_err_msg = str(sys.exc_info()[0:2])
		# print('Here is the third part: ' + traceback.format_exc())
		raise RuntimeError('try_it() error trap while running ' + func_name \
			+ ': '  + str(err_nbr) + '.  ' \
			+ str(err_msg) + '  Python error info: ' + python_err_msg)

	return(rc)

################################################################################
def nm_err_dict(calling_func_name, msg_not_logged=None,
	show_traceback=True, out={}):
	"""
	Print a brief msg on the server consol about an error and format
	the error message in a dictionary object so that the calling
	routine can converit it to JSON.

	The message will come from sys.exc_info() and from any
	raise() commands issued earlier.

	The msg_not_logged string is optional and might show transaction
	info that might be best omitted from the log.
	"""
	global ERR_LOG_TO_FILE
	global LOGFILE


	event_code = base64.b16encode(os.urandom(4)).decode('utf-8')

	msg_1 = str(sys.exc_info()[0:2]) + '. Event: ' + event_code
	if show_traceback:
		if len(sys.exc_info()) > 2 and sys.exc_info()[2]:
			# call the traceback only if the third thing in the tuple
			# is not None.
			msg_2 = 'Event: ' + event_code + '. ' + traceback.format_exc()

	# Console message:
	print('++++++++++' + calling_func_name + '|' + msg_1)

	log_msg= '|'.join(['++++++++++D', 
		datetime.datetime.now().strftime("%Y%m%d %H:%M:%S"),
		msg_1, msg_2])
	 

	if ERR_LOG_TO_FILE:
		try:
			with open(LOGFILE, 'a') as l_file:
					print(log_msg, file=l_file)
		except:
			# This message is printed to the console
			print('ERROR. Failed to write to log. event: ' + event_code \
				+ ' file: ' + repr(LOGFILE))

	out.update({'status': 'Error'})
	out.update({'Error': msg_1})
	#out.update({'Error-detail': msg_2})

	print('=== once int nm_err_dict, returning: ' + repr({calling_func_name: out} ))
	return({calling_func_name: out})

################################################################################
################################################################################

def err_log(rc, exception_text, extra_msg=None  ):
	"""
	This will be called from all of the natural message
	routines to record error messages.  There will
	be a global setting to enable or disable the copying
	of error messages to a log file.

	Send the Python stack trace to a log file but not to
	the client.  Return only the text that will
	be used by the wrapper to raise an exception.

	There should be a way to rotate the logs -- maybe
	an external process will change the value of LOGFILE
	every day.

	Maybe for a small number of intrusion-detection routines,
	this script would allow the caller to send the IP, and
	this will display only the first few bytes of the IP
	and mask the end??
	"""
	global ERR_LOG_TO_FILE
	global LOGFILE

	err_msgs = []
	exc = sys.exc_info()

	err_msgs.append('++++++++++')
	err_msgs.append(datetime.datetime.now().strftime("%Y%m%d %H:%M:%S") )
	err_msgs.append(str(rc))
	err_msgs.append(safe_string(exception_text))
	err_msgs.append(safe_string(exc[0:2]))
	if len(exc) > 2 and exc[2]:
		# call the traceback only if the third thing in the tuple
		# is not None.
		err_msgs.append(traceback.format_exc())

	if extra_msg:
		err_msgs.append( safe_string(extra_msg))

	msg = '|'.join(err_msgs)

	if ERR_LOG_TO_FILE:
		try:
			with open(LOGFILE, 'a') as l_file:
					print(msg, file=l_file)
		except:
			# This message is printed to the console
			print('ERROR. Failed to write to log file: ' + repr(LOGFILE))

	# return only the text for the excepton/error -- do not
	# send the Python traceback or details because it goes to clients
	# and might be tempting for hackers.
	return(safe_string(rc) + ': ' + safe_string(exception_text))

def log_err(rc, val, key='Error', client_version=None, IP=None, show_python_err=False):
	"""
	THIS IS THE OLD VERSION, STOP USING IT.
	THIS IS THE OLD VERSION, STOP USING IT.
	THIS IS THE OLD VERSION, STOP USING IT.
	THIS IS THE OLD VERSION, STOP USING IT.

	This will be called from all of the natural message
	routines to record error messages.  There will
	be a global setting to enable or disable the copying
	of error messages to a log file.

	An external cron job should be used to rotate and kill
	log files.  Nobody should log client information via
	these logs.

	Maybe for a small number of intrusion-detection routines,
	this script would allow the caller to send the IP, and
	this will display only the first few bytes of the IP
	and mask the end??
	"""
	global ERR_LOG_TO_FILE
	global LOGFILE

	if show_python_err:
		sys_msg = str(sys.exc_info()[0:2])
		if sys_msg is None:
			err_msg = val
		else:
			err_msg = val + '...  PYTHON ERR MSG from the shard server (MIGHT NOT BE FROM THIS ERROR TRAP): ' + sys_msg
	else:
		err_msg = val

	if ERR_LOG_TO_FILE:
		try:
			with open(LOGFILE, 'a') as l_file:
				print(datetime.datetime.now().strftime("%Y%m%d %H:%M:%S") + '|' \
					+ str(rc) + '|' + key + '|' + err_msg, file=l_file)
		except:
			# This message is printed to the console
			print('ERROR. the log file name is not set properly in shardfuncs: ' \
				+ repr(LOGFILE))

	return({'status': key, key: err_msg})



def json_keyval(key, val, leading_comma=False):
	'''This will take a key and value and format
	them as a sting: value (key: value) with quotes,
	perhaps with a comma to separate pairs.
	'''

	s = [] 
	global json_blocks_printed

	if key is not None:
		if json_blocks_printed > 0:
			s.append(',\n')

		if val is not None:
			s.append('  "' + key + '": "' + val + '"')
		else:
			s.append('"' + key + '": ""')
	else:
		s.append('"Error": "json_keyval was called without a value for key."') 
		return(12)


	json_blocks_printed += 1
	return(' '.join(s))

def shard_connect(conn_str):
	out = {}
	conn = None
	try:
		conn = psycopg2.connect(conn_str)
	except(TypeError):
		out.update({'Error-detail': repr(sys.exc_info())})
		out.update({'Error': 'There was a data type error when trying to connect to the PostgreSQL database.'})
		return((conn, out))
	except(psycopg2.ProgrammingError):
		out.update({'Error-detail': repr(sys.exc_info())})
		out.update({'Error': 'Could not connect to the PostgreSQL server.  Did the admin restart the postgre server?'})
		return((conn, out))
	except:
		out.update({'Error-detail': repr(sys.exc_info())})
		out.update({'Error': 'Some other type of error during conneciton to the PostgreSQL database.'})
		return((conn, out))

	return((conn, out))


def shard_sql_insert(cur, cmd):
	# I SHOULD UPDATE THIS TO CLOSE THE CONECTION BEFORE EXITING
	# OR IMPLEMENT A TRAP TO DO SO.
	# run sql inser with some traps.
	# So far the error traps are not accurate

	# initialize three return values
	out_msg = {}
	rc = 0

	try:
		cur.execute(cmd)
################################################################################
	except(psycopg2.IntegrityError):
		out_msg.update({'Error': 'There was a data integrity problem, such as ' \
			+ 'duplicate key in the PostgreSQL database.'})
		rc = 13001

	except(psycopg2.DataError):
		out_msg.update({'Error': 'There was a data problem, such as value too ' \
			+ 'big for the insert target field.'})
		rc = 13020

	except(psycopg2.ProgrammingError):
		#   Check /var/log/httpd/error_log or /var/lib/pgsql/data/pg_log on the server
		out_msg.update({'Error': 'SQL for inserting into a table failed.'})
		rc = 13030

	except:
		out_msg.update({'Error': 'Some other error during SQL insert.'})
		rc = 13040
	
	return((rc, out_msg))


def shard_sql_select(cur, cmd, binary_output=False):

	# initialize three return values
	out_msg = {}
	rc = 0
	rows = None

	try:
		cur.execute(cmd)
	except(psycopg2.ProgrammingError):
		out_msg.update({'Error-detail': repr(sys.exc_info())})
		out_msg.update({'Error':  'SQL error while reading from the table.'})
		rc = 13050
	except(psycopg2.IntegrityError):
		out_msg.update({'Error-detail': repr(sys.exc_info())})
		out_msg.update({'Error': 'Data integrity error from the database.'})
		rc = 13060
	except(psycopg2.DataError):
		out_msg.update({'Error-detail': repr(sys.exc_info())})
		out_msg.update({'Error': 'There was a data problem, such as value too big for the insert target field--probably not needed for a read operation.'})
		rc = 13070
	except(TypeError):
		out_msg.update({'Error-detail': repr(sys.exc_info())})
		out_msg.update({'Error': 'There was a TYPE error, possibly in the command sent to the cur.excute() function.'})
		rc = 13080
	except:
		out_msg.update({'Error-detail': repr(sys.exc_info())})
		out_msg.update({'Error': 'Unhandled error during SQL.'})
		rc = 13085

	rows = None
	try:
		rows = cur.fetchall()
	except:
		pass

	return((rc, rows, out_msg))


def validate_id_chars(id_chunk):
	"""
	This will take the portion of a box_id/shard_id...
	and confirm that the charcters are 0-9 or A-F (or a-f)
	and underline and hypen. Each program should upcase
	the box_id to standardize appearance.
	my joins need to be standardized, so each script
	should upcase the box_ids before using them.
	"""
	out_msg = {}
	rc = 0

	tmp1 = re.sub(r'[0-9A-Fa-f]+', '', id_chunk) # remove hex chars
	tmp2 = re.sub(r'[_-]+', '', tmp1)
	if (len(tmp2) != 0):
		# bad characters remain
		out_msg.update({'Error': 'Illegal characters (' + tmp2 + ') in the random part of the id: ' + id_chunk})
		rc = 13090
		return((rc, out_msg))
		#raise Exception('Illegal characters in ID')

	return((rc, out_msg))


def verify_id_format(id, expected_prefix, version=1):
	'''
	This function will check an ID to see if it has the proper
	character set and length.  The random part of the id
	must have the characters in validate_id_chars(), which
	are HEX chars or _ or -.

	If the prefix is a PUB or PRV key, then it will 
	checked against the existing shard.box_translator
	table to see if the accounts are unique.

	This does not check the complexity of the randomness.
	'''

	# Function:
	# Use regular expressions to remove good characters,
	# then see if there is anything left.
	# Example of the re library:
	#   >>> s = 'abcdefg1234a#@+sdfljsad97ADFADSF1234!@#$%^&*('
	#   >>> re.sub(r'\w+', '', s)
	#   '#@+!@#$%^&*('

	out_msg = {}
	rc = 0

	global RESERVED_EMAIL_DEST_ID


	if id == RESERVED_EMAIL_DEST_ID:
		# Accept the reserved email-transport ID
		return((rc, out_msg))
		
	if expected_prefix is None:
		out_msg.update({'Error': 'There was no expected_prefix passed to verify_id_format.'})
		rc = 13100
		return((rc, out_msg))

	if id is None:
		out_msg.update({'Error': 'There was no ID passed to verify_id_format.'})
		rc = 13110
		return((rc, out_msg))

	if (id[0:3] not in ('PUB', 'PRV', 'SID', 'SMD', 'MIX')):
		out_msg.update({'Error': 'Invalid ID prefix: ' + id[0:3]})
		#raise Exception('Illegal ID length')
		rc = 13120
		return((rc, out_msg))

	if (id[0:3] != expected_prefix):
		out_msg.update({'Error': 'The prefix (' + id[0:3] \
			+ ') was not what was expected (' + expected_prefix + ').'})

		rc = 13130 
		return((rc, out_msg))

	if (expected_prefix in ('SID', 'SMD', 'MIX')):
		# shard IDs have no embedded date or fingerprint,
		# and have 32 character random component
		if (len(id) == 35):
			# Good so far. Verify that the random part of the 
			# ID has valid characters
			rc, msg = validate_id_chars(id[3:])
			if ( rc  != 0):
				out_msg.update( msg)
				rc = 13140
				return((rc, out_msg))
		else:
			out_msg.update({'Error': 'Length of a shard ID must be 35. Observed length was: ' + str(len(id))})
			#raise Exception('Illegal ID length')
			rc = 13150
			return((rc, out_msg))

	else:
		# PUB key and PRV (prv has expiration date 40010101)
		if (len(id) == 141):
			# Good so far. Keep checking.
			# charcter format offset 0-2 = prefix; 3-4 = reserved;
			# 5-12 = yyyymmdd; 13-52 = fingerprint; 53-84 = random
			rc, msg = validate_id_chars(id[13:])
			if ( rc != 0):
				out_msg.update(msg)
				rc = 13160
				return((rc, out_msg))

			test_yyyymmdd = int(id[5:13])
			test_mm = int(id[9:11])
			test_dd = int(id[11:13])
			if (id[0:3] == 'PRV'):
				if (test_yyyymmdd != 40010101):
					# private boxes don't expire
					out_msg.update({'Error': "The expiration date for PRV IDs should be 40010101, but this one is:" + str(test_yyyymmdd)})
					rc = 13170
					return((rc, out_msg))
			else:
				if (test_yyyymmdd > ID_CUTOFF_YYYYMMDD):
					out_msg.update({'Error': "The expire date for this account is too far in the future zzz: " + str(test_yyyymmdd)})
					out_msg.update({'Error-detail': 'You sent ID: ' + id})
					rc = 13180
					return((rc, out_msg))

				if (test_yyyymmdd < CURRENT_YYYYMMDD):
					out_msg.update({'Error': "This ID has expired on: " + str(test_yyyymmdd)})
					rc = 13190
					return((rc, out_msg))

				if (test_mm > 12):
					out_msg.update({'Error': "invalid month for ID: " + str(test_mm)})
					rc = 13200
					return((rc, out_msg))

				if (test_mm > 31):
					out_msg.update({'Error': "invalid day for ID: " + str(test_dd)})
					rc = 13210
					return((rc, out_msg))

		else:
			out_msg.update({'Error': 'Length of ID must be 85 (3-letter code, 2-byte reserved, 8-byte date, 40 bytes server fingerprint, 32 bytes random).  I found length=' + str(len(id)) + ' for id: ' + id})
			#raise Exception('Illegal ID length')
			rc = 13215
			return((rc, out_msg))


	return((rc, out_msg))


def gpg_enc_str(readable, default_gpg_id, recipient_gpg_id, output_fname, clobber=False):
	"""gpg_enc_str will read a io.StringIO() string that can be read
	with read() and it will encrypt it to the specified recipient GPG ID and
	send it to the specified output file.  If the user specified '-' as the filename,
	the output will go to STDOUT.
	"""
	# This version expects a io.StrinigIO() object. To read bytes
	# object, make a modified copy of this and remove the bytes command inside communicate().
	# When "gpg --output" is followed by '-', the output goes to STDOUT.

	out = {}
	rc = 0

	if not clobber:
		if os.path.isfile(output_fname):
			try:
				os.rename(output_fname, output_fname + datetime.datetime.now().strftime("%Y%m%d%H%M%S"))
			except:
				out.update({'gpg_enc_strError': sys.exc_info()[1]})
				out.update({'Error': 'Could not rename existing file: ' + output_fname})
				rc = 13217
				return((rc, out))
	else:
		# Ok to clobber the file, but I will rename it.
		if os.path.isfile(output_fname):
			try:
				os.remove(output_fname)
			except:
				out.update({'gpg_enc_strError': sys.exc_info()[1]})
				out.update({'Error': 'Output file exists and I can not remove it: ' + output_fname})
				rc = 13220
				return((rc, out))

	# -- the stuff above is clobber/overwrite -- now do the encryption
	try:
		# I removed the '-' fname sep 8
		# '--homedir', NATMSG_ROOT + '/.gnupg',
		# YOU MUST LOG IN USING THE natmsg USER id, THEN RUN THE SUDO COMMAND
		# TO START THE SERVER BECAUASE THE GPG-AGENT IS NOW MANDATORY
		# AND IT WON'T WORK IF YOU LOG IN AS ROOT due to permissions problems
		gpg_process = subprocess.Popen(['gpg', '-e', '-a', '--default-key', default_gpg_id, 
			'--homedir', '/home/natmsg/.gnupg',
			'--use-agent', '--recipient',  recipient_gpg_id,   '--output', 
			output_fname, '--batch'], stdin=subprocess.PIPE)
	except:
		out.update({'gpg_enc_strError': sys.exc_info()[1]})
		out.update({'Error': 'Could not initiate the subprocess to call GPG.'})
		rc = 13230
		return((rc, out))

	try:
		gpg_out = gpg_process.communicate(bytes(readable.read(), 'utf8'))
	except:
		out.update({'gpg_enc_strError': sys.exc_info()[1]})
		out.update({'Error': 'Could not encrypt data with GPG.'})
		rc = 13235
		return((rc, out))

	if (gpg_process.returncode == 2):
		out.update({'Error': 'GPG failed with error code 2. You might need to sign the dest public key using the gpg --default-key YOUR_PRV_KEY --sign-key DEST_PUB_KEY and be sure that you set the --default-key so that you know that the default private key used here is the same one used to sign the public key.'})
		#out.update({'gpg_enc_strError': sys.exc_info()[1]})
		out.update({'GPGoutput': gpg_out})
		rc = 13240
		return((rc, out))
	elif (gpg_process.returncode !=0):
		out.update({'Error': 'GPG failed'})
		#out.update({'gpg_enc_strError': sys.exc_info()[1]})
		out.update({'GPGoutput': gpg_out})
		rc = 13250
		return((rc, out))

	out.update({'status': 'OK'})
	return((rc, out))
	# ===========


############################################################


# MOVE THIS TO shardfunc_cp2.PY
def gpg_decrypt(input_fname, output_fname, default_key=None, homedir=None, overwrite=False):
	"""gpg_decrypt will read a binary file that is addressed to a private key that this server
	holds in its default gpg homedir.  The decrypted file will be written to the output
	filename, or to STDOUT if the filename is set to '-'.
	"""
	out = {}
	rc = 0

	if not overwrite:
		if os.path.isfile(output_fname):
			msg = 'Output file exists and overwrite=False: ' + output_fname
			rc = 15
			out.update(log_err(rc, msg))
			return((rc, out))
	else:
		if os.path.isfile(output_fname):
			try:
				os.remove(output_fname)
			except:
				msg = 'Overwrite option was wet to True, but could not remove the existing file: ' + output_fname
				rc = 151
				out.update(log_err(rc, msg))
				return((rc, out))

	process_list = []

	# If there are additional command-line arguments for gpg,
	# put them at the beginning of the argument list.
	if homedir is not None:
		process_list.extend(['--homedir', homedir])

	if default_key is not None:
		process_list.extend(['--default-key', default_key])

	process_list = ['gpg', '-d', '--use-agent', '--output', output_fname, '--batch', input_fname]

	try:
		gpg_process = subprocess.Popen(process_list, stdin=subprocess.PIPE)
	except:
		out.update({'_pdecrypt_strError': sys.exc_info()[1]})
		msg = 'Could not initiate the subprocess to call GPG.'
		rc = 17
		out.update(log_err(rc, msg))
		return((rc, out))

	try:
		gpg_out = gpg_process.communicate()
	except:
		out.update({'gpg_decrypt_strError': sys.exc_info()[1]})
		msg = 'Could not decrypt data with GPG.'
		rc = 171
		out.update(log_err(rc, msg))
		return((rc, out))

	if (gpg_process.returncode == 2):
		# Not sure if this applies to decrytping -- it does apply to encryption.
		msg = 'GPG failed with error code 2. You might need to sign the dest public key using the gpg --default-key YOUR_PRV_KEY --sign-key DEST_PUB_KEY and be sure that you set the --default-key so that you know that the default private key used here is the same one used to sign the public key. From gpg: ' + gpg_out
		rc = 2
		out.update(log_err(rc, msg))
		return((rc, out))
	elif (gpg_process.returncode !=0):
		msg = 'GPG failed in gpg_decrypt:' + gpg_out
		rc = 25
		out.update(log_err(rc, msg))
		return((rc, out))

	out.update({'status': 'OK'})
	return((rc, out))





class nm_dict_to_plist(object):
	"""class nm_dict_to_plist(object)

	This class was designed to help convert
	a table of database attributes to a plist 
	format.  There is a library for Python 3.4 that
	would help to do this, but I am not sure
	if everybody has 3.4 yet (I didn't when
	I wrote this, RH).
	"""
	def __init__(self, name, data, ofile_name=sys.stdout):
		"""__init__(self, name, data)

		The value for 'name' will be the name of the tag
		that encloses the array of dictionarys.  Example:
		'shardServers' if you a creating a list of attributes
		of shard servers.
		The data object here is a python dictionary that 
		contains an array of dictionary objects. It looks like
		the following, where the words 'key' 'string' and 
		'integer' are written exactly as shown, and the 
		other values can be whatever you want them to be.
		Those other values must always be text, nothing 
		that is represented by a python numeric object.

		d = {'dict':[{'key': 'address', 'string': 'https://aaaa:443'}, 
		{'key': 'description', 'string': 'the abc server'},
		{'key': 'trust_level', 'integer': '5'},
		{'key': 'owner_name', 'string': 'Anne Anderson'},
		{'key': 'owner_info_url', 'string': 'https://anne.blog.com'},
		{'key': 'geo_zone', 'string': 'North America'},
		{'key': 'country', 'string': 'USA'} ]}
		"""
		self.name = name
		self.top = ET.Element( 'dict') # name
		self.data = []
		## self.a = ET.SubElement(self.top, 'array')
		if(type(data) != type({})):
			rc = 1237
			msg = 'nm_dict_to_plist needs to receive a dictionary object' \
				+ 'that contains an array of little dictionaries.'
			out.update(log_err(rc,msg))
			return({'nm_dict_to_plist': out})

		for d in data['dict']:
			##tmpa = ET.SubElement(self.a, 'dict')
			self.data.append(self.top)
			d_idx = len(self.data) - 1
			if d['key'] is not None:
				tmp = ET.SubElement(self.data[d_idx], 'key')
				tmp.text = d['key'].strip()

				try:
					if d['string'] is not None:
						tmp = ET.SubElement(self.data[d_idx], 'string')
						tmp.text = d['string'].strip()
				except:
					pass

				try:
					if d['integer'] is not None:
						tmp = ET.SubElement(self.data[d_idx], 'integer')
						tmp.text = d['integer'].strip()
				except:
					pass
					
	def show(self):
		"""show()
		display xml format 
		"""
		tree = ET.ElementTree(self.top)
		tree.write(ofile_name)

	def get_element(self):
		return self.top

class RNCrypt_zero(RNCryptor.RNCryptor):
	"""
	This is a modified RNCryptor for Python 3 that 
	does two things:

	  1) omits the conversion to str() after decryption unless the
	  user passes an extra option to conver to string after
	  decryption.  This is needed so that I can
	  encrypt and decrypt binary files that are invalid
	  under UTF-8.

	  2) Changes the hash iterations (for the password) to zero.
	  This is done because I hash the password once when
	  the web admin starts the server, then when I run
	  encryption and decryption routines, I don't have to
	  wait a half second for every call.

	This modified version should be used used ONLY for
	LOCAL data -- meaning that you should not send encrypted files
	to other users because other users (of Natural Message) will
	have the default iteration count and will not be able to
	read something encrypted with this.

	"""
	# This class overrides one thing in the original RNCryptor:
	# 1. iterations is now 0 because I already hashed
	# the SHARD_PW_BYTES thing hundreds of thousands of times
	# (so I can do the PBKDF2 loop once instead of once per shard).
	# I changed the hash algo in the hmac to sha246 because
	# it was faster than the default for some reason.
	# The SHA in the HMAC will function maninly to catch data errors.
	def _pbkdf2(self, password, salt, iterations=0, key_length=32):
		return KDF.PBKDF2(password, salt, dkLen=key_length, count=iterations,
		prf=lambda p, s: hmac.new(p, s, hashlib.sha256).digest())


	def post_decrypt_data(self, data, decrypt_to_str=False):
		""" Removes useless symbols which appear over padding for AES (PKCS#7). """

		## data = data[:-bord(data[-1])]
		# Python 3 does not need the bord command
		data = data[:-data[-1]]
		# Bob expanded the old'to_str' to avoid copying the setup macros.
		# (not tested in python 2).
		if decrypt_to_str:
			if isinstance(data, bytes):
				data = data.decode( 'utf-8')

		return (data)

	def decrypt(self, data, password, decrypt_to_str=False):
		data = self.pre_decrypt_data(data)
		# Bob expanded the old 'to_bytes' this to avoid copying the setup macros
		if not isinstance(password, bytes):
			password = bytes(password, 'utf-8')

		n = len(data)

		version = data[0]
		options = data[1]
		encryption_salt = data[2:10]
		hmac_salt = data[10:18]
		iv = data[18:34]
		cipher_text = data[34:n - 32]
		hmac = data[n - 32:]

		encryption_key = self._pbkdf2(password, encryption_salt)
		hmac_key = self._pbkdf2(password, hmac_salt)

		if self._hmac(hmac_key, data[:n - 32]) != hmac:
			raise Exception("Bad data")

		decrypted_data = self._aes_decrypt(encryption_key, iv, cipher_text)

		return self.post_decrypt_data(decrypted_data, decrypt_to_str=decrypt_to_str)


	## If I remove the thing that forces RNCryptor decryptions to be str,
	## then I would have to wrapt the shard_read resutls in another layer
	## of base 64.
	### # The Bob version removes the to_str()	command, which might have
	### # been added to the Python version of RNCryptor as part of the
	### # mediation between python 2 an 3, which handle utf8 and bytes
	### # differently
	### def post_decrypt_data(self, data):
	### 	""" Removes useless symbols which appear over padding for AES (PKCS#7). """
	### 	data = data[:-data[-1]]
	### 	return (data)

### Test the cryptor tool
## cryptor = RNCrypt_zero()
## cryptor.encrypt(data, pw)

##############################
### move this to shardfuncs::
def __sign_data(nonce=None):
	"""This routine will sign the nonce	with the online private
	key for this shard server. This should be called
	only from sign_nonce().
	This returns a python dictionary object that contains
	another dictionary with the text 'signature_b64' and then
	the base 64 text of the signed data.
	"""
	global ONLINE_PRV_SIGN_KEY_FNAME;

	if ONLINE_PRV_SIGN_KEY_FNAME == '':
		raise RuntimeError('457394: In __sign_data, the ONLINE_PRV_SIGN_KEY_FNAME is missing. ' \
		+ 'This value should be set from the shard server during initialzation.')

	# ./nm_sign --in aaa --signature /dev/stdout --key zzz1OnlinePRVSignKey.key
	out = {}
	sig_b64 = None
	pgm = None
	sig = None

	if nonce is None:
		rc = 7850
		msg =  'There was no nonce passed to sign_data. You need to ' \
			+ 'pass the nonce as an argument'
		out.update(log_err(rc, msg))
		return({'sign_data': out})


	pgm = subprocess.Popen(['./nm_sign', '--in', '/dev/stdin', '--signature',  
		'/dev/stdout',  '--key',  ONLINE_PRV_SIGN_KEY_FNAME],
	stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)

	try:
		sig, err = pgm.communicate(nonce)
	except:
		print('++ Signing of nonce failed.. could not run the nm_sign program.')
		rc = 7900
		msg =  'Could not execute the nm_sign program to sign the file  ' 
		out.update(log_err(rc, msg, show_python_err=True))
		return({'sign_data': out})

	if (sig == b''):
		print('++ Signing of nonce failed. PRV key is ' + ONLINE_PRV_SIGN_KEY_FNAME)
		rc = 8000
		msg =  'Could not sign the file.  The nm_sign program gave this ' \
			+ 'error message <' + err.decode('utf-8') + '>.' \
			+ ' (ignore any error saying that secure memory was alrady allocated.)'
		out.update(log_err(rc, msg))
		return({'sign_data': out})

		
	# The signing looks good. the signature is in 'sig',
	# but it is in pythong 'bytes' format, so decode
	# before returning.
	# Also convert to b64 before returning (the b64encode()
	# function takes a bytes() object, and sig is already btes,
	# but then the result is in bytes, which needs to be decoded.
	sig_b64 = base64.b64encode(sig).decode('utf-8')
	out.update({'signature_b64': sig_b64})

	return({'sign_data': out})

def sign_nonce(nonce=None):
	"""sign_nonce (nonce)
	This will be called from nearly every page generator
	to return the detached signature in base 64 format
	for the signed nonce (if there is one).

	On success, this returns a nested dictionary that
	looks like this:
	    {'sign_data': {'signature_b64': Base64OfTheSignature}}

	This returns None if there was no nonce sent or 
	raises an error if the signing failed.
	"""
	out = {}
	# Test if the file was uploaded
	if nonce is not None:
		# __sign_data grabs a nested dictionary that looks like this:
		# {'sign_data': {'signature_b64': sig_b64}}
		sig_dict = __sign_data(bytes(nonce, 'utf-8'))

		try:
			sig_b64_dict = sig_dict['sign_data']  #['signature_b64']
		except KeyError as my_exc:
			#rc = 7740
			#msg =  'The signature did not work. The sign_data() method returned' + json.dumps(sig_dict)
			#out.update(log_err(rc, msg, show_python_err=True))
			#return({'sign_nonce': out})
			raise RuntimeError('Could not sign the nonce.') from my_exc

		# Put the python dictionary entry that contains
		# the base 64 (in ASCII hex) of the sig into the
		# output dictionary...
		#	in a format that looks like this:
		#	{'signature_b64': Base64_of_the_TheSignature}
		out.update(sig_b64_dict)
	else:
		# No nonce was passed, so return none
		#return({'sign_nonce': None})
		return(None) # may 18, 2015

	return({'sign_nonce': out})

########################################################################
###def xxxxdign2():
###    if nonce is not None:
###      sig_dict_tmp = shardfuncs.sign_nonce(nonce)
###      try:
###        sig_b64_dict = sig_dict_tmp['sign_nonce']  #['signature_b64']
###      except KeyError:
###        rc = 121100
###        msg =  'The signature did not work. The sign_nonce() method returned' \
###          + json.dumps(sig_dict_tmp) 
###        out.update(shardfuncs.log_err(rc, msg))
###        # THE FORMAT OF THE ERROR FOR serverFarmTest differs from 
###        # THE OTHERS!!.
###        return({'serverFarmTest': [], 'status':'Error', 'Error':out})
###
###			# The following command adds a key/value pari that looks like this:
###			# {'signature_b64': TheSignature}
###      out.update(sig_b64_dict) ???? update with a value, not a key/value pair
########################################################################
########################################################################

def verify_pow(nonce_hex_str, fsize, payload_sha128, pow_factor,
	bit_constant, min_bits, debug=False):

	if type(nonce_hex_str) != type(''):
		print('Error. The nonce_hex_str needs to be of type Python str()')
		return(-12)

	if debug:
		# Show the bit representation of the nonce_hex_str
		print('The nonce_hex_str sent to verify_pow was: ' \
			+ bin(int().from_bytes(nonce_hex_str, sys.byteorder)) \
			+ ' (that nonce_hex_str is added to a string and hashed)')


	# Hash_len_bytes will be hard-coded and will correspond to
	# the number of bytes that are produced by the chosen hash algo.
	hash_len_bytes = 20

	# ------------------------------------------------------------
	# The server would now verify the nonce_hex_str
	# using today's date, or yesterday's, or the day before that
	# or tomorrow's date
	good = False
	dt_adjust = (0, -1, -2, 1)
	j = 0
	while not good:
		# This loop tries to verify the POW using today's date,
		# yesterday's date, and a couple other dates.

		# Try to verify each of the days listed in dt_adjust
		dt = datetime.date.today() + datetime.timedelta(days=dt_adjust[j])

		# Create the YYYYMMDD string that goes in the hash
		# (remember leading zeroes for day and month).
		yyyymmdd_str = str(dt.year) + "%02d" % dt.month + "%02d" % dt.day

		# Recalculate the hash:
		h = hashlib.sha1(b''.join(payload_sha128, bytes( yyyymmdd_str + nonce_hex_str, 'utf-8'))).digest()

		if debug:
			print ('length of hash in verify_pow is : ' + str(len(h)) \
				+ ' for ' + repr(h))


		# Construct a bit mask.	It will contain 
		# 1-bits in the high-order part so that the
		# number of high-order 1 equals "target_bits"
		# (big-endian).
		# When the bitwise & of the mas and the "found
		# hash codes" is all 1s, then we have found
		# a key the produces the desired number of leading
		# 1-bites.
		mask = 1 << (8 * hash_len_bytes - 1)
		for i in range(target_bits - 1):
			mask = mask | 1 << (hash_len_bytes * 8 - i - 1)

		i = int().from_bytes(h, 'big')
		if mask & i == mask:
			if debug:
				print('verified with mask\n' + bin(mask) + '\nand hash\n' + bin(i))

			good = True

		j += 1

	#
	if good:
		if debug:
			print('The POW is good.')

		return(0)
	else:
		if debug:
			print('The POW is bad.')

		return(-1)

########################################################################
