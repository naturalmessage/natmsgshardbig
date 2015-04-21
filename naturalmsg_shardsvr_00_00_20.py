# naturalmsg_shardsvr_00_00_20.py

# This is a 'big' shard server for the Natural Message network.
# The current max shard size is 5MB, and the shards are stored
# in encrypted files on disk (encrypted using a password that
# the server operator enters when starting the server--
# so there are no automatic server starts!).
# There is also a 'small' shard server that stores the shards
# in the database (more efficient for small shards--wastes less
# disk space).
#
# This should be run as root--there is a dropprivileges command
# that will drop it to user natmsg (unprivileged account).
#
#
## Run ths server like this (depending on what your python3
## program is called:
#    cd /var/natmsg
#    sudo python3 naturalmsg_shardsvr_00_00_20.py
## or perhaps:
#    cd /var/natmsg
#    sudo /usr/local/bin/python3.4 naturalmsg_shardsvr_00_00_20.py
#
#
# ALl run-time options are in the configuration file in the ./conf directory.
#
test_or_prod = 'prod' 
NM_VERSION_STRING = "00_00_20" # also used in cp.id file
# The configuration (conf) file for this version of the server:
cp_config_fname = './conf/natmsg_shard_' + test_or_prod + '_' + NM_VERSION_STRING + '.conf'

SHARD_PW_BYTES = '' # This is set by the user when the server starts
SERVER_FINGERPRINT = None # This is loaded from the conf file.
print ('remember to run a couple gpg requests with --use-agent to prime the passwords')
shard_read_timer = False
DAY_CODES = ['a', 'b', 'c', 'd', 'e', 'f', 'g'] # For shard subdirectories


# These options will be set via the config file natmsg-shard-prod.conf
# The psql user names are in lower case.
srvr_enc_id='' #gpg enc ID for mix network, set in the conf file
HOSTNAME = ''
DBNAME = ''
DB_UNAME = ''
DB_PW = ''
CONN_STR = ''
ONLINE_PUB_SIGN_KEY_FNAME=''
ONLINE_PRV_SIGN_KEY_FNAME=''
ONLINE_PUB_ENC_KEY_FNAME=''
ONLINE_PRV_ENC_KEY_FNAME=''
OFFLINE_PUB_SIGN_KEY_FNAME=''

from cherrypy.process.plugins import DropPrivileges, PIDFile
import shardfunc_cp_00_00_20 as shardfuncs # 
import ssl_builtin_bob
import pbkdf2_nm
import subprocess

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
import sys
import time # for the time.sleep() function


if test_or_prod not in ('test', 'prod', 'exp'):
	print('Error. "test_or_prod" must be one of test, prod, exp.')
	sys.exit(12)

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
		try:
			fd = codecs.open('html/' + pgname,'r', 'utf8')
		except:
			pass

		if fd is None:
			return('pgname is ' + pgname)
		else:
			return(fd.read())

	@cherrypy.expose
	@cherrypy.tools.encode(encoding='UTF-8')
	def webform_admin(self):

		return("""<html>
			<head></head>
			<body>
			<p>Send an 	ENCRYPTED  message to the administrators.  The message is encrypted using the 
         webmaster&quot;s public key, and the private key is not online.</p>

			<form method="get" action="/webform_admin_process">
			<p>Enter your message below</p>

			<input type="text" SIZE=2000 MAXSIZE=7000 value="" name="msgtxt" />
			<button type="submit">Send!</button>
			</form>
			</body>
			</html>""")

	@cherrypy.expose
	@cherrypy.tools.json_out()
	def nm_version(self):
		return({'nm_version': NM_VERSION_STRING,
		'once test': repr(bin(cherrypy.wsgiserver.wsgiserver3.server.ssl_adapter.context.options))})
			

	@cherrypy.expose
	@cherrypy.tools.json_out()
	def nm_db_table_names(self, nonce=None):
		"""Dump a list of tables with their definitions.
		"""
		out={}

	
		if nonce is not None:
			sig_dict_tmp = shardfuncs.sign_nonce(nonce)
			try:
				sig_b64_dict = sig_dict_tmp['sign_nonce']  #['signature_b64']
			except KeyError:
				rc = 7740
				msg =  'The signature did not work. The sign_nonce() method returned' \
					+ json.dumps(sig_dict_tmp)
				out.update(shardfuncs.log_err(rc, msg))
				return({'validateServer': out})

			out.update(sig_b64_dict)

		conn, msg_d = shardfuncs.shard_connect(CONN_STR)
		if conn is None:
			return({'nm_db_table_names': msg_d})
		
		cur = conn.cursor()
		
		# Select \dt shard.*
		# ideas: select * from information_schema.tables;
		# select * from information_schema.columns;
		# select table_schema from information_schema.columns group by table_schema order by table_schema;
		# SELECT table_name
		# FROM information_schema.tables
		# WHERE table_type = 'BASE TABLE'
		# AND table_schema NOT IN
		#   ('pg_catalog', 'information_schema');
		#
		# SELECT * FROM information_schema.columns WHERE table_name = 'shards';
		#
		# SELECT *  FROM information_schema.columns where table_schema NOT IN ('information_schema', 'pg_catalog');

		cmd = "SELECT *  FROM information_schema.columns where table_schema NOT IN ('information_schema', 'pg_catalog');"
		rc, my_data, msg_d = shardfuncs.shard_sql_select(cur, cmd)
		if rc != 0:
			msg = 'SQL SELECT statement command failed in nm_db_table_names.'
			out.update(shardfuncs.log_err(rc, msg))
			out.update({'Error-detail-not-logged': msg_d})
			cur.close()
			conn.close()
			return({'nm_db_table_names': out})

		if my_data[0][0]:
			tb_data = {}
			recnbr = 0
			for rec in my_data:
				# for each row of data (contains information
				# on each column in the sharddb database)
				tb_data.update({str(recnbr): rec})
				recnbr = recnbr + 1

			out.update({'status': 'OK'})
			out.update({'results': tb_data})
			return({'nm_db_table_names': out})
		else:
			rc = 8100
			msg = 'Failed to get the table structure from  information_schema.'
			out.update(shardfuncs.log_err(rc, msg))
			return({'nm_db_table_names': out})


		rc = 8200
		msg = 'impossible to get to this point?'
		out.update(shardfuncs.log_err(rc, msg))
		return({'nm_db_table_names': out})


	@cherrypy.expose
	@cherrypy.tools.json_out()
	def webform_admin_process(self, msgtxt, debug=False):
		# Accept the form input from webform_admin,
		# put the textdirectly into a smd_create in JSON format,
		# send to the admin id.
		#
		# The Requests lib for python comes from
		# http://docs.python-requests.org/en/latest/user/install/#get-the-code
		# and the downloaded directory looks something like this:
		#  kennethreitz-requests-359659c

		import io
		import requests
		import base64
		#import subprocess
		import tempfile

		out = {}
		dbg = False

		# Python seems to get the data type right, but 
		# this might be safer than making assumptions.
		if type(debug) == type('str'):
			if debug.lower() in ('true', 't'):
				dbg = True
		elif type(debug) == type(True):
			if debug:
				dbg = True

		# First create a single shard, unencrypted, unsplit.
		shard_id = re.sub(r'[=]*', '', 'SID'  \
				+ bytes.decode(binascii.b2a_hex(os.urandom(16))).upper()[0:32])


		mytmp= 'tmpwebfrm' + bytes.decode(binascii.b2a_hex(os.urandom(6))).upper()[0:6]
		rc, msg_d = shardfuncs.gpg_enc_str(io.StringIO(msgtxt), 
			default_gpg_id=cherrypy.config['srvr_enc_id'], 
			recipient_gpg_id=cherrypy.config['webmaster_enc_id'], output_fname=mytmp)
		if rc != 0:
			msg = 'I could not encrypt the webform message. GPG returned ' + str(rc)
			rc = 8300 # my err nbr, not GPG's
			out.update(shardfuncs.log_err(rc, msg, show_python_err=True))

			# Error detail using msg_d from GPG.
			rc = 8400
			out.update(shardfuncs.log_err(rc, msg_d, key='GPG_ERR')) 
			return({'webform_admin_process': out})
			

		fd_enc = codecs.open(mytmp, 'r', 'utf-8')
		dat = fd_enc.read()
		fd_enc.close()
		url = 'http://127.0.0.1:80/shard_create?shard_id=' + str(shard_id)
		
		# The 'file' that I am sending is really JSON tha tis here in memory.
		attached_files = {'shard_data': ('overrideinputfilenamegoeshere', 
			dat,
			'application/x-download', {'Expires': '0'})}
		#		io.StringIO(enctxt),
		if dbg:
			out.update({'DEBUG2001': 'before request'})

		try:
			r = requests.post(url, files=attached_files)
		except:
			rc = 8500
			msg = 'I could not put the data into shard_create.'
			out.update(shardfuncs.log_err(rc, msg, show_python_err=True))
			return({'webform_admin_process': out})

		# The shard is ready, now create a smd and deliver to the admin
FIX ID XXX
		url = 'http://127.0.0.1:9090/smd_create?public_recipient=PUB0000000190DC85ED44F10BA8789CC694BAF52CE44881B649CA5D3837D455B1EF61F1EA11'

		# The "file" that I am attaching is actually JSON that is here in memory.
		# and contains only the link to the shard.
		attached_files = {'shard_metadata': ('overrideinputfilenamegoeshere', io.StringIO('{"url": "http://127.0.0.1:9090/shard_read?shard_id=' + shard_id + '"}' ), 'application/x-download', {'Expires': '0'})}

		try:
			r = requests.post(url, files=attached_files)
		except:
			rc = 8600
			msg = 'I could not post the shard metadata.'
			out.update(shardfuncs.log_err(rc, msg, show_python_err=True))
			return({'webform_admin_process': out})


		out.update({'status': 'OK'})
		if dbg:
			out.update({'DEBUG2000': repr(r.text)})
		return({'webform_admin_process': out})

	############################################################
	############################################################
	@cherrypy.expose
	@cherrypy.tools.json_out()
	def server_local_settings(self, debug=False, public_recipient=None, 
			shard_metadata=None, nonce=None):
		# These should come from settings in an option file
		global NM_VERSION_STRING

		out = {}

		if nonce is not None:
			sig_dict_tmp = shardfuncs.sign_nonce(nonce)
			try:
				sig_b64_dict = sig_dict_tmp['sign_nonce']  #['signature_b64']
			except KeyError:
				rc = 7740
				msg =  'The signature did not work. The sign_nonce() method returned' \
					+ json.dumps(sig_dict_tmp)
				out.update(shardfuncs.log_err(rc, msg))
				return({'validateServer': out})

			out.update(sig_b64_dict)


		out.update({'version': NM_VERSION_STRING})
		return({'server_local_settings': out})
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
		nonce=None, payment_key=None, nm_pow=None, debug=False, ):
		"""shard_create(shard_id, shard_data, nonce, payment_key, nm_pow, debug=False)
		This will accept an attached filed named shard_data that contains base64
		data.  If you upload binary crap, it will be rejected.
		"""
		# THIS WILL CONTAIN SHARD ENCRYPTION AND WILL EVENTUALLY HANDLE
		# ALL SHARDS FOR THE SERVER -- IT WILL HAVE ONE SIZE LIMIT FOR THE SERVER
		# WHICH CAN BE SET IN THE CONF FILE.
		global SHARD_PW_BYTES
		global DAY_CODES

		out ={} 
		dbg = False

		# Python seems to get the data type right, but 
		# this might be safter than making assumptions.
		if type(debug) == type('str'):
			if debug.lower() in ('true', 't'):
				dbg = True
		elif type(debug) == type(True):
			if debug:
				dbg = True


		if nonce is not None:
			sig_dict_tmp = shardfuncs.sign_nonce(nonce)
			try:
				sig_b64_dict = sig_dict_tmp['sign_nonce']  #['signature_b64']
			except KeyError:
				rc = 7740
				msg =  'The signature did not work. The sign_nonce() method returned' \
					+ json.dumps(sig_dict_tmp)
				out.update(shardfuncs.log_err(rc, msg))
				return({'validateServer': out})

			out.update(sig_b64_dict)

		if (shardfuncs.ALLOW_NEW_MSGS != True):
			# The flag in /opt/python3/lib/python3.4/site-packages/shardfuncs.py
			# (or wherever it is in the sys.path path),
			# has been unset. Do not allow new messages to be created,
			# but allow old ones to be read
			rc = 8700
			msg = 'The main server responded, but is not accepting new messages.'
			out.update(shardfuncs.log_err(rc, msg))
			return({'shard_create': out})
		
		if dbg:
			if shard_data is not None:
				shardfuncs.json_keyval({'DEBUG0010': 'I HAVE THE SHARD DATA.'})
				shardfuncs.json_keyval({'DEBUG0020': 'Here it is ' + repr(shard_data)})
		
		##out.update({'DEBUG0030': 'HEADERCHECK ' + repr(cherrypy.tools.response_headers.__dict__)})
		###out.update({'DEBUG0033': 'HEADERCHECK ' + repr(cherrypy.tools.__dict__)})
		###out.update({'DEBUG0035': 'HEADERCHECK ' + repr(cherrypy.tools.flatten.__dict__)})
		###out.update({'DEBUG0036': 'toolscheck  ' + repr(cherrypy.request.__dict__)})
		##out.update({'DEBUG0037': 'toolscheck  ' + repr(cherrypy.request.headers)})
		
		cont_len = 0
		is_chunked = False
		is_multipart = False


		# see if the user passed a shard_id, 
		# if so verify its format
		if shard_id is None:
			rc = 8900
			msg =  'The shard_id is missing from shard_create.'
			out.update(shardfuncs.log_err(rc, msg))
			return({'shard_create': out})
		rc, msg_d = shardfuncs.verify_id_format(shard_id, expected_prefix='SID')


		if( rc != 0):
			rc = 9000
			msg =  'The format of the shard ID was bad: '
			out.update(shardfuncs.log_err(rc, msg))

			out.update({'Error-detail-not-logged': msg_d['Error']})
			if shard_id is not None:
				if dbg:
					out.update({'DEBUG0100': 'the shard ID was %s.' % (repr(shard_id))})

			return({'shard_create': out})

		#------------------------------------------------------------
		# set up database connection
		conn, msg_d = shardfuncs.shard_connect(CONN_STR)
		if conn is None:
			return({'shard_create': msg_d})
	
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
			rc = 9100
			msg =  'SQL SELECT statement command failed in shard_create ' \
				+ 'when checking shard ID existence.'
			out.update(shardfuncs.log_err(rc, msg))

			out.update({'Error-detail-not-logged': msg_d['Error']})
			cur.close()
			conn.close()
			return({'shard_create': out})

		if my_data[0][0]:
			# Reject a request to overwrite a shard that 
			# existed recently (even if the shard data has been deleted).
			rc = 9200
			msg =  'Shard ID existed recently.  You can not overwrite shards.'
			out.update(shardfuncs.log_err(rc, msg))
			cur.close()
			conn.close()
			return({'shard_create': out})

		# Test if the file was uploaded
		if shard_data is not None:
			cryptor = shardfuncs.RNCrypt_zero()	
			# strip leading path from file name to avoid directory traversal attacks
			###fn = os.path.basename(shard_id) # add a subdirectory from last 2 chars

			# send data from shard_data to output.
			# MODIFY THIS TO GET A BLOCK AT A TIME AND STOP IF 
			# THE FILE IS TOO BIG.
			f_in = None
			try:
				f_in = shard_data.file
				dat = f_in.read() # This produces a python bytes() object.
				f_in.close()
			except:
				rc = 9300
				msg =  'Could not read the shard data from network package.  ' \
					+ "Try naming the file 'shard_data' and try again."
				out.update(shardfuncs.log_err(rc, msg, show_python_err=True))
				return({'shard_create': out})

			# random day count between about 20 and 40
			del_day_count = int((int.from_bytes(os.urandom(1), byteorder='little')) \
				/ 256.0 * 20) + 20
		
			today = datetime.date.today()
			day_code = DAY_CODES[today.weekday()]
			shard_path = '/var/natmsg/shards/' + day_code
			exp_date = datetime.date.today() + datetime.timedelta(days=6)
			del_date = datetime.date.today() + datetime.timedelta(days=del_day_count)
		
			if cherrypy.config['shard_encrypt_version'] == 1:
				# dat will now be bytes
				encrypted_data = cryptor.encrypt(dat, SHARD_PW_BYTES)
			elif cherrypy.config['shard_encrypt_version'] == 0:
				# Now that dat is bytes, unecrypted will probably cause an error,
				# but we shold not be using this anyway.
				encrypted_data = dat
			else:
				print('Unexpected shard_encrypt_version during create: ' \
					+ repr(cherrypy.config['shard_encrypt_version']))
				rc = 9500
				msg =  'The requested encryption format for shards was not' \
					+ 'expected: ' + repr(cherrypy.config['shard_encrypt_version'])
				out.update(shardfuncs.log_err(rc, msg))
				return({'shard_create': out})

			f = None
			try:
				f = open(shard_path + '/' + shard_id, 'wb')
			except:
				rc = 9600
				msg =  'Failed to open the shard file for writing.'
				out.update(shardfuncs.log_err(rc, msg, show_python_err=True))
				return({'shard_create': out})

			try:
				if isinstance(encrypted_data, bytes):
					# writing binary 
					f.write(encrypted_data)
				else:
					f.write(bytes(encrypted_data, 'utf-8'))
			except:
				rc = 9605
				msg =  'Failed to write the shard to disk.'
				out.update(shardfuncs.log_err(rc, msg, show_python_err=True))
				return({'shard_create': out})

			f.close()
		
		
			# The sql command wants the date in a an odd format, so do it here.
			# PostgreSQL wants the date like this, including the quotes: '2014-09-29'::date 
			expire_dt_sql = "'" + str(exp_date.year) + "-" + str(exp_date.month).zfill(2) + "-" \
				+ str(exp_date.day).zfill(2) + "'::date "
		
			del_dt_sql = "'" + str(del_date.year) + "-" + str(del_date.month).zfill(2) + "-" \
				+ str(del_date.day).zfill(2) + "'::date "
		
		
			# Note that the code here does not need to add quotes around the date values.
			cmd = "INSERT INTO shardsvr.big_shards(" \
			+ "  big_shard_id, " \
			+ "  delete_db_entry_on_date, " \
			+ "  expire_on_date, " \
			+ "  encryption_format, " \
			+ "  day_code) " \
			+ "values('%s', %s, %s, %d, '%s');" % (shard_id, \
			del_dt_sql , \
			expire_dt_sql, \
			cherrypy.config['shard_encrypt_version'], \
			day_code)
		
		
			rc, msg_d = shardfuncs.shard_sql_insert(cur, cmd)
			if rc != 0:
				rc = 9700 # the other rc is irrelevant
				msg =  'SQL insert command failed in shard_create.'
				out.update(shardfuncs.log_err(rc, msg))

				rc = 9800
				out.update(rc, msg_d, key='Error-detail')

				cur.close()
				conn.close()
				return({'shard_create': out})
			else:
				cur.execute('commit;')
				cur.close()
				conn.close()
				out.update({'status': "OK"})
				
			cur.close()
			conn.close()
		
		else:
			rc = 9900
			msg =  'No file was uploaded.  You must upload a file with the post parameter name "shard_data".'
			out.update(shardfuncs.log_err(rc, msg))


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
		"""
		### WARNING. IF YOU UPDATE THIS ROUTINE
		### CHECK IF THE SERVERVALIDATION() METHOD
		### NEEDS THE SAME CHANGES.
		global SHARD_PW_BYTES

		big_data = None
		out ={} 
		dbg = False
		cont_len = 0
		is_chunked = False
		is_multipart = False

		# Python seems to get the data type right, but 
		# this might be safter than making assumptions.
		if type(debug) == type('str'):
			if debug.lower() in ('true', 't'):
				dbg = True
		elif type(debug) == type(True):
			if debug:
				dbg = True

		if nonce is not None:
			sig_dict_tmp = shardfuncs.sign_nonce(nonce)
			try:
				sig_b64_dict = sig_dict_tmp['sign_nonce']  #['signature_b64']
			except KeyError:
				rc = 7740
				msg =  'The signature did not work. The sign_nonce() method returned' \
					+ json.dumps(sig_dict_tmp)
				out.update(shardfuncs.log_err(rc, msg))
				return({'validateServer': out})

			out.update(sig_b64_dict)

		## out.update({'DEBUG0030': 'HEADERCHECK ' + repr(cherrypy.tools.response_headers.__dict__)})
		## #out.update({'DEBUG0033': 'HEADERCHECK ' + repr(cherrypy.tools.__dict__)})
		## #out.update({'DEBUG0035': 'HEADERCHECK ' + repr(cherrypy.tools.flatten.__dict__)})
		## #out.update({'DEBUG0036': 'toolscheck  ' + repr(cherrypy.request.__dict__)})
		## out.update({'DEBUG0037': 'toolscheck  ' + repr(cherrypy.request.headers)})
		
		for k, v in cherrypy.request.headers.items():
			if k.lower() == 'content-length':
				is_chunked = False
				cont_len = int(v)
			elif k.lower() == 'transfer-encoding' and 'chunked' in v.lower():
				is_chunked = True

			if k.lower() == 'content-type' and 'multipart' in v.lower():
				is_multipart = True
		
		# see if the user passed a shard_id, 
		# if so verify its format
		if shard_id is None:
			rc = 10000
			msg =  'The shard_id was missing in shard_read.'
			out.update(shardfuncs.log_err(rc, msg))
			return({'shard_read': out})

		rc, msg_d = shardfuncs.verify_id_format(shard_id, expected_prefix='SID')

		if( rc != 0):
			rc = 11000
			msg = 'The format of the shard ID was bad: '
			out.update(shardfuncs.log_err(rc, msg))

			out.update({'Error-detail': msg_d['Error']})
			if shard_id is not None:
				if dbg:
					out.update({'DEBUG0100': 'the shard ID was %s.' % (repr(shard_id))})

			return({'shard_read': out})

		conn, msg_d = shardfuncs.shard_connect(CONN_STR)
		if conn is None:
			return({'shard_read': msg_d})

		cur = conn.cursor()

		cmd = str("SELECT burned, expired, delete_db_entry_on_date, " \
			+ "encryption_format, day_code " \
			+ "FROM shardsvr.big_shards " \
			+ "WHERE  big_shard_id = '%s';" % (shard_id))

		my_data = None
		rc, my_data, msg_d = shardfuncs.shard_sql_select(cur, cmd)
		if rc != 0:
			rc = 6700
			msg = 'SQL SELECT statement command failed in shard_read.'
			out.update(shardfuncs.log_err(rc, msg))

			out.update({'Error-detail-not-logged': msg_d['Error']})
			cur.close()
			conn.close()
			return({'shard_read': out})

		## REMOVED NOV 19 FOR SHARD BURN cur.close()
		## REMOVED NOV 19 FOR SHARD BURN conn.close()

		### test out.update({'rc': repr(rc)})
		### test out.update({'msg_d': repr(msg_d)})
		### test out.update({'my_data': repr(my_data)})
		### test return({'shard_read': out})
		
		if my_data is None:
			rc = 6800
			msg = 'SQL fetch of the shard data failed.'
			out.update(shardfuncs.log_err(rc, msg))
			cur.close()
			conn.close()
			return({'shard_read': out})

		if len(my_data) > 0:
			# The "[0][0]" array notation here selects the first data row 
			# (row #0) and the first col (col #0), and the next one
			# gets data from the second column (col # 1).
			brn = my_data[0][0]
			exp = my_data[0][1]
			del_date = my_data[0][2]
			encryption_format = my_data[0][3]
			day_code = my_data[0][4]
			if day_code == ' ':
				shard_path = '/var/natmsg/shards'
			else:
				shard_path = '/var/natmsg/shards/' + day_code

			## print('shard_read TEST: ' + repr(my_data))
			## print('shard_read TEST: ' + repr(brn))
			## print('shard_read TEST: ' + repr(exp))
			## print('shard_read TEST: ' + repr(del_date))

			if not brn and not exp:
				# The shard has not burned and not expired

				cryptor = shardfuncs.RNCrypt_zero()	
				try:
					f = open(shard_path + '/' + shard_id, 'rb')
				except:
					rc = 6900
					msg = 'Could not open the shard for reading.'
					out.update(shardfuncs.log_err(rc, msg))
					try:
						cur.close()
						conn.close()
					except:
						pass
					return({'shard_read': out})
				if encryption_format == 1:
					# Read the data and decrypt using the
					# method that was coded in the database
					# for this shard.  This would theoretically
					# Allow me to change the encryption method
					# on a live server -- code newly created
					# shards with the new algo, and the olds ones
					# will be processed with the old one, until
					# the old ones are all gone in 5 or so days.
					try:
						dat_in = f.read()
					except:
						f.close()
						rc = 7000
						msg = 'Error reading the shard file.'
						out.update(shardfuncs.log_err(rc, msg, show_python_err=True))
						out.update({'errdetail': repr(sys.exc_info()[0])})
						try:
							cur.close()
							conn.close()
						except:
							pass
						return({'shard_read': out})

					f.close()

					try:
						# The regular RNCryptor (in early 2015) expected str output
						# so use Bob's override version here. This now returns bytes().
						big_data = cryptor.decrypt(dat_in, SHARD_PW_BYTES)
					except:
						rc = 7001
						msg = 'Error decrypting the shard file.  The umodified RNCryptor routine seems to expect UTF-8, ' \
								+ 'but I use a modified post_decrypt routine to avoid this error.  If you see this error, ' \
								+ 'it could mean that you need to restore my RNCryptor class redefinition.'
						out.update(shardfuncs.log_err(rc, msg, show_python_err=True))
						out.update({'errdetail': repr(sys.exc_info()[0])})
						try:
							cur.close()
							conn.close()
						except:
							pass
						return({'shard_read': out})

					dat_in = None

				elif encryption_format == 0:
					# We always use encryption, so this line should not run
					big_data = f.read()
					f.close()
				else:
					rc = 7100
					msg = 'Unknown encryption format returned for this shard.'
					out.update(shardfuncs.log_err(rc, msg))
					try:
						cur.close()
						conn.close()
					except:
						pass
					return({'shard_read': out})


				if (big_data is None):
					rc = 7200
					msg = 'OOPS. I do not have the big data'
					out.update(shardfuncs.log_err(rc, msg))
					try:
						cur.close()
						conn.close()
					except:
						pass
					return({'shard_read': out})
				else:
					# RETURN THE DATA xxx
					# RETURN THE DATA xxx
					# RETURN THE DATA xxx
					# RETURN THE DATA xxx
					# RETURN THE DATA xxx
					# RETURN THE DATA xxx
					cherrypy.response.headers['Content-Type'] = 'application/x-download'
					if not isinstance(big_data, bytes):
						big_data = bytes(big_data, 'utf-8')

					return(big_data)
			else:
				if brn:
					rc = 7300
					msg = 'The shard has already been read: ' + shard_id 
					out.update(shardfuncs.log_err(rc, msg))
					try:
						cur.close()
						conn.close()
					except:
						pass
					return({'shard_read': out})
				elif  datetime.date.today() > del_date or exp:
					rc = 7400
					msg = 'The shard has expired (too old).'
					out.update(shardfuncs.log_err(rc, msg))
					try:
						cur.close()
						conn.close()
					except:
						pass

					return({'shard_read': out})
			
			# INSERT THE big SHARD DELETION PROCESS HERE.
			# RUN THE STORED PREOCEDURE TO DELETE AND SET ALL THE FLAGS
			# INSERT THE SHARD DELETION PROCESS HERE.
			# RUN THE STORED PREOCEDURE TO DELETE AND SET ALL THE FLAGS
			# INSERT THE SHARD DELETION PROCESS HERE.
			# RUN THE STORED PREOCEDURE TO DELETE AND SET ALL THE FLAGS

			# The burn process is done in two steps:
			#  1) run the shard_burn(shard_id) stored procedure,
			#  2) erase the shard from disk.
			if not brn and not exp:
				# The shard has not burned and not expired,

				smd_data = None
				# Burn the shard using the shard_delete stored procedure: 
				cmd = "SELECT * FROM shardsvr.shard_burn('%s');" % (shard_id)
				rc, smd_data, msg_d = shardfuncs.shard_sql_select(cur, cmd)
				#### older: #if rc == 0:
				## nov 19
				if smd_data is None:
					rc = 7500
					msg = 'SQL delete statement failed.'
					out.update(shardfuncs.log_err(rc, msg))
					out.update({'Error-Detail': repr(msg_d)})
					try:
						cur.close()
						conn.close()
					except:
						pass
					return({'shard_read': out})

				if smd_data[0] == 0:
					rc = 7600
					msg = 'SQL delete statement command returned 0 rows. ' \
						+ 'Transaction was rolled back.'
					out.update(shardfuncs.log_err(rc, msg))
					try:
						cur.close()
						conn.close()
					except:
						pass
					return({'shard_read': out})

				# erase the shard file
				os.remove(shard_path + os.path.sep + shard_id)
		
		else:
			out.update({'Error': 'The SQL select ran, but the big shard was not found.'})
			out.update({'Error-detail': repr(my_data) + repr(msg_d)})
			try:
				cur.close()
				conn.close()
			except:
				pass
			return({'shard_read': out})

		# final return
		out.update({'status': "OK"})
		try:
			cur.close()
			conn.close()
		except:
			pass
		return({'shard_read': out})

	############################################################
	############################################################
	############################################################
	############################################################
	############################################################
	############################################################
	@cherrypy.expose
	@cherrypy.tools.json_out()
	def webform_admin_inbox_read(self, debug=False):
		# This will read the speical, unencrypted webform data
		# for the admin account
		import io
		import requests
		import base64

		out={}

		# read the inbox
		# PRV0000000103A409C79F4561CEF2D03BF2EF09A4FC09B38D0BCF692CFD7954443391AFE147
		
		url = 'http://127.0.0.1:80/inbox_read?dest_private_box_id=PRV0000000103A409C79F4561CEF2D03BF2EF09A4FC09B38D0BCF692CFD7954443391AFE147'
		try:
			r = requests.post(url)
		except:
			out.update({'Error': 'I could not read the inbox for the admin webform stuff'})
			return({'webform_admin_inbox_read': out})

		##out.update({'test': r.text})
		try:
			# j is a dictionary object
			j = json.loads(r.text)
		except:
			out.update({'Error': 'I could not get the JSON from the inbox.'})
			return({'webform_admin_inbox_read': out})

		idx = 0
		bad_msg_count = 0
		for k, v in j['inbox_read'].items():
			if len(k) == 75:
				# This dictionary item will contain a JSON object that
				# contains a few keys, including shard_metdata.
				
				## out.update({'Message' + str(idx): v['shard_metadata']})
				shard_url = None
				try:
					shard_url = json.loads(v['shard_metadata'])['url']
				except:
					# Show the python error info and exit.
					# Later I will simply note the error and continue
					out.update({'Error': repr(sys.exc_info()[0])})
					return({'webform_admin_inbox_read': out})
					
				# ----------------------------------------
				# I have a shard_url, now grab it.
				try:
					r = requests.post(shard_url)
				except:
					out.update({'Error': 'I could not put the data into shard_create.'})
					return({'webform_admin_process': out})

				try:
					# try to get the content of the message within the JSON
					msg_j = json.loads(r.text)['shard_read']['shard_data']
				except:
					out.update({'Error': repr(sys.exc_info()[0])})
					out.update({'Error-detail': r.text})
					return({'webform_admin_inbox_read': out})

				out.update({'realmsg' + str(idx): msg_j})
			idx += 1

		#out.update({'test2': j['inbox_read']['shard_metadata']})
		return({'webform_admin_inbox_read': out})
		
	############################################################
	############################################################
	@cherrypy.tools.json_out()
	@cherrypy.expose
	def validateServer(self, nonce=None, debug=False):
		"""validateServer
		This will accept a small file (a nonce) that the server
		will sign with its online private key and return
		a detached signature file.

		The client can verify the server using this process:
		1) Using the result of this requist, as the 'signature'
		   of the original nonce.
		2) Grab the 'signature of the online key by the offline key'
		   for the server in question and confirm that signature.
		   That info is available in the serverFarm web page on
		   the main Natural Message server.
		3) confirm that the fingerprint in the server config file
		   matches the SHA384 of the offline public key.
		Note that the main Natural Message operator will check
		for any changes in the online key that are inconsistent
		with historical data.

		This routine contains of the shard_create (big) method
		from dec 2014 because I was not sure how some of the
		information would be handled internally.  This might
		be better if there was a common routine that was called
		by shard_create and this.
		"""

		# Function:
		# 1) read a 'shard' that contains the nonce (maybe allow only tiny file sizes).
		# 2) Run a python subprocess to call the C program 
		#    to sign the nonce (I am calling a C program because I 
		#    did not find a good python library for libgcrypt by itself
		#    and there was a conflict between version of libgcrypt
		#    capabilities for 1.5 and 1.6).

		out ={} 
		dbg = False
		sig_b64_dict = None
		sig_dict_tmp = None


		# Python seems to get the data type right, but 
		# this might be safer than making assumptions.
		if type(debug) == type('str'):
			if debug.lower() in ('true', 't'):
				dbg = True
		elif type(debug) == type(True):
			if debug:
				dbg = True

		if nonce is not None:
			sig_dict_tmp = shardfuncs.sign_nonce(nonce)
			try:
				sig_b64_dict = sig_dict_tmp['sign_nonce']  #['signature_b64']
			except KeyError:
				rc = 7740
				msg =  'The signature did not work. The sign_nonce() method returned' \
					+ json.dumps(sig_dict_tmp)
				out.update(shardfuncs.log_err(rc, msg))
				return({'validateServer': out})

			out.update(sig_b64_dict)
			
		else:
			# Empty nonce
			rc = 7800
			msg =  'There was no nonce passed to validateServer. You need to ' \
				+ 'upload a file called "nonce".'
			out.update(shardfuncs.log_err(rc, msg))
			return({'validateServer': out})

		# final return
		return({'serverValidate': out})

	
	############################################################
	############################################################
	############################################################
	############################################################
	############################################################
	@cherrypy.expose
	@cherrypy.tools.json_out()
	def canary(self, nonce=None):
    # canary msg.
		# This will eventually read a database table and show
		# the newest entry.  The json should be accompanied by
		# a detached sig using a private key that is not online.
		out = {}
##		out.update({'prolegomena': {'author': 'Robert Hoot', 'date': 'Sep 9, 2014', 'title': 'webmaster', 'contact_id': 'PUB1111111xyz', 'alert_key': 'Alert level 0 means that there is nothing interesting to report.  Alert level 5 means that something very very very interesting has happened or is about to happen.', 'status_archives': 'https://naturalmessage.com/notreayyet'}, 'alert_level': 0, 'statements': {'statement01': 'The SSL secret keys for this web site have not been supplied to any outside person or agency--no keys for any machines on this site have been compromised (to the best of my knowledge).', 'statement02': 'I have not inserted any malware or spyware to enable any outsider to gain access to any client information that is obtained from any of the machines that comprise this web site.', 'statement03': 'I have not worked with any person or agency to defeat any security feature of this site or any of the shard servers that are accessed by this site.', 'statement04': 'I have taken precautions to prevent unauthoried access to this machine, and I have no new report of any security breachs.', 'statement05': 'I have not been tortured related to my free speech activities or my involvement with this web site', 'statement06': 'I am not aware of any person who is involved in server operations is under pressure from an outside person or agency to comprimise the security of this web site.', 'statement07': 'In this calendar month, I have responded to warrants that affect 0 users.'}})

		if nonce is not None:
			sig_dict_tmp = shardfuncs.sign_nonce(nonce)
			try:
				sig_b64_dict = sig_dict_tmp['sign_nonce']  #['signature_b64']
			except KeyError:
				rc = 7740
				msg =  'The signature did not work. The sign_nonce() method returned' \
					+ json.dumps(sig_dict_tmp)
				out.update(shardfuncs.log_err(rc, msg))
				return({'validateServer': out})

			out.update(sig_b64_dict)

		return(out)


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
		#   a) if there is a delay for this action, (in minutes that I round +- 30 sec)
		#      save the JSON to a file, generate a key if there isn't one
		#      in the JSON, send the time and the key to the 
		#      remix_pending database.
		#   b) if action is 'forward,' extract the 
		#      embedded attachement and send it
		#      to the next server via remix_packet()
		#   c) if the action is 'save', save the shard.
		## I SHOULD REFACTOR THIS AGAIN TO USE THE SAME CORE
		## AS shard_read	WITH OPTIONS FOR THE JSON FUNCTION NAME,
		## and INPUT ROUTINE.


		out ={} 
		dbg = False

		# Python seems to get the data type right, but 
		# this might be safter than making assumptions.
		if type(debug) == type('str'):
			if debug.lower() in ('true', 't'):
				dbg = True
		elif type(debug) == type(True):
			if debug:
				dbg = True


		if nonce is not None:
			sig_dict_tmp = shardfuncs.sign_nonce(nonce)
			try:
				sig_b64_dict = sig_dict_tmp['sign_nonce']  #['signature_b64']
			except KeyError:
				rc = 7740
				msg =  'The signature did not work. The sign_nonce() method returned' \
					+ json.dumps(sig_dict_tmp)
				out.update(shardfuncs.log_err(rc, msg))
				return({'validateServer': out})

			out.update(sig_b64_dict)

		### if (shardfuncs.ALLOW_REMIX != True):
		### 	# The flag in /opt/python3/lib/python3.4/site-packages/shardfuncs.py
		### 	# (or wherever it is in the sys.path path),
		### 	# has been unset. Do not allow new messages to be created,
		### 	# but allow old ones to be read
		### 	out.update({'Error' ,'The main server responded, but is not accepting new remix requests.'})
		### 	return({'remix_packet':out})
		
		
		if dbg:
			if shard_data is not None:
				shardfuncs.json_keyval({'DEBUG0010': 'I HAVE THE SHARD DATA.'})
				shardfuncs.json_keyval({'DEBUG0020': 'Here it is ' + repr(shard_data)})
		
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

		
		mix_id = re.sub(r'[=]*', '', 'MIX'  \
				+ bytes.decode(binascii.b2a_hex(os.urandom(16))).upper()[0:32])
		rc, msg_d = shardfuncs.verify_id_format(mix_id, expected_prefix='MIX')

		if( rc != 0):
			out.update({'Error': 'The format of the mix ID was bad: '})
			out.update({'Error-detail': msg_d['Error']})
			if mix_id is not None:
				out.update({'DEBUG0100': 'the mix ID was %s.' % (repr(mix_id))})
			return({'remix_packet': out})

		
		# Test if the file was uploaded
		if shard_data is not None:
			# save the shard data to a shard data file that has
			# a 'mix id' as a file name:
			# MODIFY THIS TO GET A BLOCK AT A TIME AND STOP IF 
			# THE FILE IS TOO BIG.
			f_in = shard_data.file
			f = open('/var/natmsg/shards/' + mix_id, 'w')
			f.write(f_in.read().decode('utf8'))
			f.close()
			f_in.close()
		
		conn, msg_d = shardfuncs.shard_connect(CONN_STR)
		if conn is None:
			return({'remix_packet': msg_d})
		
			cur = conn.cursor()
		
		
			# random day count between about 20 and 40
			del_day_count = int((int.from_bytes(os.urandom(1), byteorder='little')) / 256.0 * 20) + 20
		
			today = datetime.date.today()
			exp_date = datetime.date.today() + datetime.timedelta(days=6)
			del_date = datetime.date.today() + datetime.timedelta(days=del_day_count)
			###yyyymmdd = str(today.year) + str(today.month).zfill(2) + str(today.day).zfill(2) 
		
		
			# The sql command wants the date in a an odd format, so do it here.
			# PostgreSQL wants the date like this, including the quotes: '2014-09-29'::date 
			expire_dt_sql = "'" + str(exp_date.year) + "-" + str(exp_date.month).zfill(2) + "-" \
				+ str(exp_date.day).zfill(2) + "'::date "
		
			del_dt_sql = "'" + str(del_date.year) + "-" + str(del_date.month).zfill(2) + "-" \
				+ str(del_date.day).zfill(2) + "'::date "
		
		
			# Note that the code here does not need to add quotes around the date values.
			cmd = "INSERT INTO shardsvr.big_shards(" \
			+ "  big_shard_id, " \
			+ "  delete_db_entry_on_date, " \
			+ "  expire_on_date) " \
			+ "values('%s', %s, %s);" % (mix_id, \
			del_dt_sql , \
			expire_dt_sql )
		
			rc, msg_d = shardfuncs.shard_sql_insert(cur, cmd)
			if rc != 0:
				out.update({'Error': 'SQL insert command failed in remix_packet.'})
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
			out.update({'Error': 'No file was attached to the remix packet.  You must upload a file with the post parameter name "shard_data".'})
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
	SHARD_PW_BYTES =  pbkdf2_nm.pw_hash(verify_fname='/var/natmsg/shard_server_receiptV2.save')
	if SHARD_PW_BYTES is None:
		print('The shard password is bad.  Quitting now.')
		sys.exit(12)

	# The config file contains ip, port, fingerprint, 
	# and a few other things:
	cherrypy.config.update(cp_config_fname)

	cp_id_fname = cherrypy.config['natmsg_root'] + os.sep + 'cp_shard_' + NM_VERSION_STRING + '.pid'
	# I will now load a cusomized version of 
	# /usr/local/lib/python3.4/site-packages/cherrypy/wsgiserver/ssl_builtin.py
	# to make my own ssl-adapter because the default one is
	# hard-coded to accept SSLv3 or higher, and I don't want SSL v3.
	my_ssl_adapter = ssl_builtin_bob.BuiltinSSLAdapter( \
		cherrypy.config['server.ssl_certificate'],
		cherrypy.config['server.ssl_private_key'])

	cherrypy.wsgiserver.wsgiserver3.ssl_adapters.update({"bob": "ssl_builtin_bob.BuiltinSSLAdapter"})

	# Connection keep-alive is depricated because connections are kept open until Connection: close is sent by the server?
	#('Connection', 'close'), 
	conf = {
		'global':{'request.show_tracebacks':True,
		'server.ssl_module': 'bob',
		'log.access_file': '',
		'log.screen': True,
		'tools.response_headers.on': True,
		'tools.response_headers.headers': [('Cache-Control', ' no-cache,no-store,max-age=0'), ('Strict-Transport-Security', '')]
		},
		'/': {
		'tools.sessions.on': False,
		'tools.staticdir.root': os.path.abspath(os.getcwd())
		},
		'/account_create': {
		'tools.response_headers.on': True,
		'tools.response_headers.headers': [('Connection', 'close'), ('Cache-Control', ' no-cache,no-store,max-age=0'),  ('Strict-Transport-Security', '')]
		},
		'/shard_create': {
		'tools.response_headers.on': True,
		'tools.response_headers.headers': [('Connection', 'close'), ('Cache-Control', ' no-cache,no-store,max-age=0'),  ('Strict-Transport-Security', '')]
		},
		'/shard_read': {
		'tools.response_headers.on': True,
		'tools.response_headers.headers': [('Connection', 'close'), ('Cache-Control', ' no-cache,no-store,max-age=0'),  ('Strict-Transport-Security', '')]
		},
		'/shard_create': {
		'tools.response_headers.on': True,
		'tools.response_headers.headers': [('Connection', 'close'), ('Cache-Control', ' no-cache,no-store,max-age=0'),  ('Strict-Transport-Security', '')]
		},
		'/webform_admin_process': {
		'tools.response_headers.on': True,
		'tools.response_headers.headers': [('Connection', 'close'), ('Cache-Control', ' no-cache,no-store,max-age=0'),  ('Strict-Transport-Security', '')]
		},
		'/webform_admin_inbox_read': {
		'tools.response_headers.on': True,
		'tools.response_headers.headers': [('Connection', 'close'), ('Cache-Control', ' no-cache,no-store,max-age=0'),  ('Strict-Transport-Security', '')]
		},
		"/favicon.ico":
		{
			"tools.staticfile.on": True,
			"tools.staticfile.filename":
						 "/var/natmsg/html/favicon.png"
		},
		'/static': {
		'tools.staticdir.on': True,
		'tools.staticdir.dir': './public'
		},
		'/validateServer': {
		'tools.response_headers.on': True,
		'tools.response_headers.headers': [('Cache-Control', ' no-cache,no-store,max-age=0'), ('Connection', 'keep-alive'), ('Content-Type', 'application/x-download')]
		}
	}
	
	##'tools.response_headers.headers': [('Transfer-Encoding', 'chunked'), ('Content-Type' 'text/html;charset=utf-8'), ('Connection', 'keep-alive')]


	##cherrypy.engine.subscribe('start', setup_database)

	##cherrypy.engine.subscribe('stop', cleanup_database)

	# server pidfile (this registers the ID number of the running
	# instance as shown in 'ps -A' terminal command). 
	if os.path.isfile(cp_id_fname):
		print('Error. the program ID file already exists: ' \
			+ cp_id_fname + '.')
		print('Maybe there is another instance using this file ' \
			+ 'or it is there from a prior crash.')
		sys.exit(9012)

	PIDFile(cherrypy.engine, cp_id_fname).subscribe()

	if cherrypy.config['SERVER_FINGERPRINT'] is None:
		print('Error.  The SERVER_FINGERPRINT setting is not set.')
		print('Set this in the natmsg-prod.cfg (or -test) file.')

	else:
		SERVER_FINGERPRINT = cherrypy.config['SERVER_FINGERPRINT']
		print('The server fingerprint from the external option file ' \
			+ 'is: ' + SERVER_FINGERPRINT)


	#input('press a key to continue...')
	HOSTNAME = cherrypy.config['HOSTNAME']
	DBNAME = cherrypy.config['DBNAME']
	DB_UNAME = cherrypy.config['DB_UNAME']
	DB_PW = cherrypy.config['DB_PW']
	ONLINE_PUB_SIGN_KEY_FNAME=cherrypy.config['ONLINE_PUB_SIGN_KEY_FNAME']
	ONLINE_PRV_SIGN_KEY_FNAME=cherrypy.config['ONLINE_PRV_SIGN_KEY_FNAME']
	ONLINE_PUB_ENC_KEY_FNAME=cherrypy.config['ONLINE_PUB_ENC_KEY_FNAME']
	ONLINE_PRV_ENC_KEY_FNAME=cherrypy.config['ONLINE_PRV_ENC_KEY_FNAME']
	OFFLINE_PUB_SIGN_KEY_FNAME=cherrypy.config['OFFLINE_PUB_SIGN_KEY_FNAME']

	CONN_STR = "host=" + HOSTNAME + " dbname=" + DBNAME + " user=" + DB_UNAME + " password='" + DB_PW + "'"
	# pass some data to shardfuncs
	shardfuncs.ONLINE_PRV_SIGN_KEY_FNAME=cherrypy.config['ONLINE_PRV_SIGN_KEY_FNAME']
	shardfuncs.LOGFILE = cherrypy.config['LOGFILE']

	#- - - - - - - - - - - - - - - - - - - - 
	# test if the database is online
	conn, msg_d = shardfuncs.shard_connect(CONN_STR)
	if conn is None:
		print('Error. Could not connect to the datase.  Is it Running?  Try running /root/psqlgo.sh for the natural message start script.')
		sys.exit(15)
	#- - - - - - - - - - - - - - - - - - - - 

	# The user needs to call this with root privileges,
	# then the following command drops to the natmsg user ID.
	DropPrivileges(cherrypy.engine, gid=cherrypy.config['dropto_gid'], 
		uid=cherrypy.config['dropto_uid']).subscribe()
	webapp = StringGenerator()
	#webapp.generator = StringGeneratorWebService()
	cherrypy.quickstart(webapp, '/', conf)
	# The quickstart command above is short for the tree.mount, server start, 
	# and cherrypy.engine.start().
