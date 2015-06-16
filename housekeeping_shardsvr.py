#!/bin/env python3

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
# This program shouuld be scheduled to run daily to
# delete old, unread shards. Put in a crontab like this:
#    sudo -u natmsg crontab -e
# and put lines like this into the crontab:
#    * 2 * * * /usr/local/bin/python3 /home/natmsg/shard_housekeeping.py
#
# You can also run this manually, but double check
# the full path to the correct python3 program:
#    sudo -u natmsg /usr/local/bin/python3 shard_housekeeping.py
#
# There is a SEPARATE command for the monitor, which runs
# under the root user id:
# sudo crontab -e
#    */5 * * * * /usr/local/bin/python3 /home/natmsg/monitor.py
#


# This will call a stored procedure (properly called
# a 'PostgreSQL user function') to identify and flag 
# shards that have expired, then this python script 
# will remove those shard files and also delete 
# old shard records from the database at the approprieate
# time.  Note the the database records are kept after
# the file is deleted-- this is to give a proper notice to
# the client that the shard has expired, and also
# to avoid an attack that relias on the ability
# to rewrite shards under old names (within the
# window when the client might try to retrieve them).
#

import configparser
import sys
import os
import datetime
import traceback
import psycopg2

shard_dir = '/var/natmsg/shards'
# the psql user names are in lower case

# These are loaded from conf/housekeeping_shardsvr.conf
CONFIG_FNAME = '/var/natmsg/conf/housekeeping_shardsvr.conf'
HOSTNAME = ''
DBNAME = ''
DB_UNAME = 'shardsvr'
DB_PW = ''

################################################################################

def shard_sql_select(conn, cur, cmd, binary_output=False):
	"""
	This function was borrowd from shardfunc_cp.

	Peform an SQL select and trap a few errors.

	It is up to the caller to close cursors and connections
	when appropriate.
	"""
	# initialize three return values
	out_msg = {} # previously used for err msgs
	rc = 0
	rows = None

	try:
		cur.execute(cmd)
	except(psycopg2.ProgrammingError) as my_exc:
		cur.close()
		conn.close()
		raise RuntimeError('Error: SQL error while reading from the table.') from my_exc
	except(psycopg2.IntegrityError) as my_exc:
		cur.close()
		conn.close()
		raise RuntimeError('Error: Data integrity error from the database.') from my_exc
	except(psycopg2.DataError) as my_exc:
		cur.close()
		conn.close()
		raise RuntimeError('Error: There was a data problem, such as value too big ' \
			+ 'for the insert target field--probably not needed for a ' \
			+ 'read operation.') from my_exc
	except(TypeError):
		cur.close()
		conn.close()
		raise RuntimeError('Error: There was a TYPE error, possibly in the command ' \
			+ 'sent to the cur.excute() function.')
	except Exception as my_exc:
		cur.close()
		conn.close()
		raise RuntimeError('Error: Unhandled error during SQL.') from my_exc

	rows = None
	if cur.rowcount >= 0:
		try:
			rows = cur.fetchall()
		except:
			print(help(cur))
			cur.close()
			conn.close()
			raise RuntimeError('Error: Failed to fetch rows SQL.') from my_exc

	return((rc, rows, out_msg))


################################################################################
################################################################################

if __name__ == '__main__':

	CONFIG_FNAME = '/var/natmsg/conf/housekeeping_shardsvr.conf'

	MAIN_CONFIG = configparser.ConfigParser()

	MAIN_CONFIG.read(CONFIG_FNAME)

	DBNAME = MAIN_CONFIG['global']['DBNAME']
	HOSTNAME = MAIN_CONFIG['global']['HOSTNAME']
	DB_UNAME = MAIN_CONFIG['global']['DB_UNAME']
	DB_PW = MAIN_CONFIG['global']['DB_PW']


	if DBNAME == '' or DB_UNAME == '' or DB_PW == '' or HOSTNAME == '':
		print('Error, database connection details are missing.')
		sys.exti(15)

	##############################################################################
	datestamp = datetime.datetime.now()
	datestamp_sql = "'" + str(datestamp.year) + "-" \
		+ str(datestamp.month).zfill(2) \
		+ "-"  + str(datestamp.day).zfill(2) + ' ' \
		+ str(datestamp.hour).zfill(2) \
		+ ':' +  str(datestamp.minute).zfill(2) + ':' \
		+ str(datestamp.second).zfill(2) +  "'::timestamp "
	## print('datestamp: ' + datestamp_sql)

	############################################################
	# register the ssl keys and a few shards that
	# I create that should never be read
	out = {}
	conn_str = "host=" + HOSTNAME + " dbname=" \
		+ DBNAME + " user=" + DB_UNAME + " password=" + DB_PW

	## print('test conn_str ' + conn_str)
	try:
		conn = psycopg2.connect(conn_str)
	except(TypeError):
		print('Error: There was a data type error when trying to ' \
			+ 'connect to the PostgreSQL database.')
		sys.exit(12) # temp exit
	except(psycopg2.ProgrammingError):
		print('Error: Could not connect to the PostgreSQL server.  ' \
			+ 'Did the admin restart the postgre server?')
		sys.exit(12) # temp exit
	except Exception as my_exc:
		raise RuntimeError('Error: Some other type of error during conneciton ' \
			+ 'to the PostgreSQL database.') from my_exc

	cur = conn.cursor()
	#------------------------------------------------------------
	#  PART I. RUN A STORED PROCEDURE/'USER FUNCTION' TO
	#  IDENTIFY THE SHARDS TO EXPIRE.
	#
	# Transactions are loaded to shardsvr.shard_big_kill_pending().
	#

	# When I run this stored procedure, it will
	# identify shards that need to be deleted.
	# It will flag the shards as expired in the
	# shardsvr.shards table, and it will put 
	# the list of shards in
	# shard.shard_big_kill_pending table.
	cmd = 'SELECT shardsvr.shard_big_expire();'
	my_data = None

	rc, my_data, msg = shard_sql_select(conn, cur, cmd)
	if rc != 0:
		print('Error: SQL insert command failed.')
		print('Error-detail:' +  msg['Error'])
		cur.close()
		conn.close()
		print('ERROR 111:  ' + repr(msg))
		sys.exit(12) # temp exit


	if my_data is None:
		print('No shards to delete. All done.')
		cur.close()
		conn.close()
		sys.exit(0)

	if my_data and my_data[0][0] == 0:
		print('Note. The scan for expired shards found nothing.')
		cur.close()
		conn.close()
		sys.exit(0)

	#------------------------------------------------------------
	#  PART II. DELETE THE SHARD FILES FROM DISK

	cmd = 'SELECT big_shard_id from shardsvr.shard_big_kill_pending;'
	my_data = None

	rc, my_data, msg = shard_sql_select(conn, cur, cmd)
	if rc != 0:
		print('Error: SQL insert command failed.')
		print('Error-detail' + msg['Error'])
		cur.close()
		conn.close()
		print('ERROR 888:  ' + repr(msg))
		sys.exit(12) # temp exit

	failed_del_list = []
	removed_file_count = 0
	for row_dat in my_data:
		shard_id = row_dat[0]
		fname = shard_dir + '/%s' % (shard_id.strip())
		## print('removing this file: ' + fname)
		try:
			os.remove(fname)
		except:
			# Allow the loop to continue even if a particular
			# delete failed -- don't let one problem
			# leave unburned shards.
			failed_del_list.append(fname)
			continue

		removed_file_count += 1


	print('I removed ' + str(removed_file_count) + ' shard files.')
	print('==== list of failed deletes: ' + repr(failed_del_list))

	#------------------------------------------------------------
	#  PART III. DELETE RECORDS FROM THE shard_big_kill_pending
	#															 TRANSACTION TABLE.
	# -- Now kill all the records in shard_big_expire
	cmd = 'DELETE FROM shardsvr.shard_big_kill_pending;'
	my_data = None

	rc, my_data, msg = shard_sql_select(conn, cur, cmd)
	if rc != 0:
		print('Error: SQL insert command failed.')
		print('Error-detail' + msg['Error'])
		conn.close()
		print('ERROR 777:  ' + repr(msg))
		sys.exit(12) # temp exit

	# the sql-write loop is done, now commit
	cur.execute('commit;')
	# do not conn.close() until the end (or on error)


	#------------------------------------------------------------
	#												 PART IV: EXPIRE LITTLE SHARDS
	# This detects shards in the database that have an
	# expire_on_date that has past.  The underlying
	# table is shardsvr.shards.

	cmd = 'SELECT shardsvr.shard_expire();'
	my_data = None

	rc, my_data, msg = shard_sql_select(conn, cur, cmd)
	if rc != 0:
		print('Error: SQL insert command failed.')
		print('Error-detail'  + msg['Error'])
		conn.close()
		print('ERROR 666:  ' + repr(msg))
		sys.exit(12) # temp exit

	if my_data[0][0] == 0:
		print('WARNING. The scan for expired shards found nothing.')
	else:
		print('I expired ' + str(my_data[0][0]) + ' little shards')

	#------------------------------------------------------------
	#									 PART V: DELETE DATABASE RECORDS OF SHARDS
	# This removes the database entries for old shards if the
	# delete_on_date has past.  It deletes from table 
	# shardsvr.scan_shard_delete.
	#
	# Remember that the actual shards are delted within about 
	# 5 days of creation, and only the record of the shard ID
	# remains to prevent recreating the same shard).

	cmd = 'SELECT shardsvr.shard_delete_db_entries();'
	my_data = None

	rc, my_data, msg = shard_sql_select(conn, cur, cmd)
	if rc != 0:
		print('Error SQL insert command failed.')
		print('Error-detail ' + msg['Error'])
		conn.close()
		print('ERROR 555:  ' + repr(msg))
		sys.exit(12) # temp exit

	if my_data[0][0] == 0:
		print('WARNING. The scan for deletable shards found nothing.')
	else:
		print('I deleted ' + str(my_data[0][0]) + ' shards database records')
	#------------------------------------------------------------
	cur.close()
	conn.close()
