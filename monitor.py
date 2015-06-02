#!/bin/env python3

# GPL V3 license
# Author: Robert E. Hoot
# 




# This will eventually monitor system resources
# and send the info to a database.

import configparser
import datetime
import json
import psycopg2
import re
import shardfunc_cp
import subprocess
import sys

CONFIG_FNAME = '/var/natmsg/conf/housekeeping_shardsvr.conf'
MAIN_CONFIG = None

# The psql user names are in lower case
HOSTNAME = ''
DBNAME = ''
UNAME = 'shardwebserver'
PW = ''


#del_date = datetime.date.today() + datetime.timedelta(days=del_day_count)
#del_dt_sql = "'" + str(del_date.year) + "-" + str(del_date.month).zfill(2) + "-" \
#	+ str(del_date.day).zfill(2) + "'::date "
datestamp = datetime.datetime.now()
datestamp_sql = "'" + str(datestamp.year) + "-" + str(datestamp.month).zfill(2) + \
	"-"  + str(datestamp.day).zfill(2) + ' ' + str(datestamp.hour).zfill(2) + ':' + \
	str(datestamp.minute).zfill(2) + ':' + str(datestamp.second).zfill(2) +  "'::timestamp "
print('datestamp: ' + datestamp_sql)




def mon_file(fname):
	"""
	Monitor some file statistics.
	"""
	rc = 0
	out = {}
	cmd_lst = ['stat',  '-c', '{"%n": {"inode": %i, "access_time": %X, "mod_time": %Y, "change_time": %Z, "file_type": %T }}', fname]

	p = None
	p = subprocess.Popen(cmd_lst, stdout=subprocess.PIPE)
	if p is None:
		out.update({'Error': 'Subprocess for stat command failed.'})
		rc = 12
		return((rc, {"mon_file": out}))

	try:
		rslt = p.communicate()[0].decode('utf-8')
	except:
		out.update({'Error': 'Failed to initiate the process for the stat command.'})
		rc = 12
		return((rc, {"mon_file": out}))

	try:
		j = json.loads(rslt)
	except:
		print('Error executing the subprocess command for stat.')
		print('Filename was ' + fname)
		return(12)

	out.update(j)
	return((rc, {"mon_file": out}))

###def proc_stat():
###	# This grabs some CPU system info and puts it in JSON format.
###	# I probably should have used vmstat instead.
###	#
###	# The file layout for 'cpu' lines in /proc/stat:
###	# * user: normal processes executing in user mode
###	# * nice: niced processes executing in user mode
###	# * system: processes executing in kernel mode
###	# * idle: twiddling thumbs
###	# * iowait: waiting for I/O to complete
###	# * irq: servicing interrupts
###	# * softirq: servicing softirqs
###
###	rc = 0
###	out = {}
###	##cat /proc/stat|grep "^cpu"|tr -s ' '|tr ' ' '|'|sed -e 's/\([[a-z0-9]*\)[|]\([0-9]*\)[|]\([0-9]*\)[|]\([0-9]*\)[|]\([0-9]*\)[|]\([0-9]*\)[|]\([0-9]*\)[[:print:]]*/{"cpu": {"cpu_name": "\1", "cpu_user": \2, "cpu_nice": \3, "cpu_system": \4, "cpu_idle": \5, "cpu_wait": \6}/'
###		
###	with open('/proc/stat', 'r') as fd:
###		dat = fd.readlines()# .decode('utf-8')
###
###	for l in dat:
###		# Read one line of data, remove the EOL marker and squeze multiple spaces
###		# down to one space.
###		s = re.sub(r'[ ]{1,50}', ' ', l.rstrip('\n'))
###		parsed = s.split(' ')
###		if parsed[0].lower() == 'cpu':
###			# I found a cpu line: 
###			# Note that parsed[0] refers to the first word on the input line.
###			#print('{"' + parsed[0] + '": {"cpu_user": ' + parsed[1] + ', "cpu_nice": ' \
###			#		+ parsed[2] + ', "cpu_system": ' + parsed[3] + ', "cpu_idle": ' + parsed[4] \
###			#		+ ', "cpu_wait": ' + parsed[5] + '}}')
###			out.update({ parsed[0]: {"cpu_user": parsed[1], "cpu_nice":  \
###				parsed[2], "cpu_system": parsed[3], "cpu_idle": parsed[4], \
###				"cpu_wait": parsed[5] }})
###		elif parsed[0][0:13].lower() == 'procs_running':
###			# I found a procs_running line:
###			#print('{"procs_running": ' + parsed[1] + '}')
###			#out.update({"procs_running": parsed[1] })
###			out.update({parsed[0]: int(parsed[1]) })
###		elif parsed[0][0:13].lower() == 'procs_blocked':
###			# I found a blocked line:
###			out.update({parsed[0]: int(parsed[1]) })
###
###	
###	return((rc, {"proc_stat": out}))

#####
def nstat():
	rc = 0
	out = {}
	
	# CentOS 6 does not support -j for nstat
	##cmd_lst = ['nstat', '-azj']
	cmd_lst = ['nstat', '-az']

	p = None
	p = subprocess.Popen(cmd_lst, stdout=subprocess.PIPE)
	if p is None:
		out.update({'Error': 'Subprocess for stat command failed.'})
		rc = 12
		return((rc, {"nstat": out}))

	try:
		rslt = p.communicate()[0].decode('utf-8')
	except:
		out.update({'Error': 'Failed to initiate the process for the nstat command.'})
		rc = 12
		return((rc, {"nstat": out}))

	# loop through the nstat output,
	# grab desired values,
	# build a python dictionary object.
	# first compress multiple spaces into one space:
	s = re.sub(r'[ ]{1,50}', ' ', rslt.rstrip('\n'))
	# split into lines
	dat = s.split('\n')
	s = None
	for l in dat:
		# for each input line from nstat:
		flds = l.split()
		if flds[0] in ('IpExtInOctets', 'IpExtOutOctets', 'IpInReceives', 
			'TcpActiveOpens', 'TcpPassiveOpens', 'IpOutRequests'):
			## print('=== i found in' + repr(l))
			out.update({flds[0]: flds[1]})

	return((rc, {"nstat": out}))
############################################################
def ps():
	rc = 0
	out = {}
	
	cmd_lst = ['ps', '-A', '--format', 'uid,pid,ppid,time,cmd']

	p = None
	p = subprocess.Popen(cmd_lst, stdout=subprocess.PIPE)
	if p is None:
		out.update({'Error': 'Subprocess for ps command failed.'})
		rc = 12
		return((rc, {"ps": out}))

	try:
		rslt = p.communicate()[0].decode('utf-8')
	except:
		out.update({'Error': 'Failed to initiate the process for the ps command.'})
		rc = 12
		return((rc, {"ps": out}))

	# loop through the ps output,
	# grab desired values,
	# build a python dictionary object.
	# first compress multiple spaces into one space:
	s = re.sub(r'[ ]{1,50}', ' ', rslt.rstrip('\n'))
	# split into lines
	dat = s.split('\n')
	s = None
	past_header = False
	for l in dat:
		if past_header:
			# for each input line from ps:
			# uid,pid,ppid,time,cmd
			flds = l.split()
			#my_cmd = re.sub(r'[^a-zA-Z \t0-9]','', flds[4][0:200])
			my_cmd = re.sub(r'[\'"\r\t\n]','', flds[4][0:200])
			my_parms = ''
			if len(flds) > 5:
				# The next line takes the list of program parmaters
				# that appear in teh extended ps listing, and retains
				# only  the essential chars that could not cause sql injection
				# or other problems.
				my_parms = re.sub(r'[^a-zA-Z \t0-9]','', ' '.join(flds[5:])[0:200])

			out.update({flds[1]: {'uid': flds[0], 'ppid': flds[2], 'time': flds[3],
				'cmd': my_cmd, 'parms': my_parms }})
		else:
			past_header = True
			pass #skip the first row of data -- it is the ps output header.
		
	return((rc, {"ps": out}))

#####
def vmstat():
	rc = 0
	out = {}
	
	cmd_lst = ['vmstat', '-S', 'K', '-s']

	p = None
	p = subprocess.Popen(cmd_lst, stdout=subprocess.PIPE)
	if p is None:
		out.update({'Error': 'Subprocess for vmstat command failed.'})
		rc = 12
		return((rc, {"vmstat": out}))

	try:
		rslt = p.communicate()[0].decode('utf-8')
	except:
		out.update({'Error': 'Failed to initiate the process for the vmstat command.'})
		rc = 12
		return((rc, {"vmstat": out}))

	# loop through the vmstat output,
	# grab desired values,
	# build a python dictionary object.
	# first compress multiple spaces into one space:
	s = re.sub(r'[ ]{1,50}', ' ', rslt.rstrip('\n'))
	# split into lines
	dat = s.split('\n')
	s = None
	for l in dat:
		# for each input line from vmstat:
		flds = l.split()
		v = int(flds[0])
		k = '_'.join(flds[1:])

		if k in ('K_total_memory', 'K_used_memory','K_active_memory', 
			'K_free_memory', 'K_swap_cache', 'K_total_swap', 'K_free_swap',
			'non-nice_user_cpu_ticks', 'nice_user_cpu_ticks', 'system_cpu_ticks',
			'idle_cpu_ticks', 'IO-wait_cpu_ticks', 'boot_time','forks'):
			out.update({k: v})

	return((rc, {"vmstat": out}))

# ------------------------------------------------------------
def rec_counts():
	# capture seq numbers from shard tables for the logger.
	pass
############################################################
############################################################
############################################################
############################################################
# register the ssl keys and a few shards that
# i create that should never be read
out = {}
conn_str = "host=" + HOSTNAME + " dbname=" + DBNAME + " user=" + UNAME + " password='" + PW + "'"
try:
	conn = psycopg2.connect(conn_str)
except(TypeError):
	out.update({'Error': 'There was a data type error when trying to connect to the PostgreSQL database.'})
	sys.exit(12) # temp exit
except(psycopg2.ProgrammingError):
	out.update({'Error': 'Could not connect to the PostgreSQL server.  Did the admin restart the postgre server?'})
	sys.exit(12) # temp exit
except:
	out.update({'Error': 'Some other type of error during conneciton to the PostgreSQL database.'})
	sys.exit(12) # temp

cur = conn.cursor()
# - - - - - - - - - - - -  - - - -  - -

rc, msg_d = vmstat()
out.update(msg_d)
rslts = None
vmstat_write_count = 0
try:
	# Get the dictionary object from the file monitor:
	rslts = msg_d['vmstat']
except:
	print('Error. I did not find vmstat output.')

if rslts is not None:
	v = rslts
	# Note: two table fields have '-' replaced with '_':
	# non-nice_user_cpu_ticks and IO-wait_cpu_ticks
	cmd = 'INSERT INTO shardsvr.sysmon_vmstat (' \
		+ 'K_total_memory, K_used_memory, K_active_memory, ' \
		+ 'K_free_memory, K_swap_cache, K_total_swap, K_free_swap, ' \
		+ 'non_nice_user_cpu_ticks, nice_user_cpu_ticks, system_cpu_ticks, ' \
		+ 'idle_cpu_ticks, IO_wait_cpu_ticks, boot_time, sysmon_vmstat_dt) ' \
		+ 'VALUES (' + str(v['K_total_memory']) + ', ' \
		+ str(v['K_used_memory']) + ', ' \
		+ str(v['K_active_memory']) + ', ' + str(v['K_free_memory']) + ', ' \
		+ str(v['K_swap_cache']) + ', ' + str(v['K_total_swap']) + ', ' \
		+ str(v['K_free_swap']) + ', ' + str(v['non-nice_user_cpu_ticks']) + ', ' \
		+ str(v['nice_user_cpu_ticks']) + ', ' + str(v['system_cpu_ticks']) + ', ' \
		+ str(v['idle_cpu_ticks']) + ', ' + str(v['IO-wait_cpu_ticks']) + ', ' \
		+ str(v['boot_time']) + ', ' + datestamp_sql + ');'

	rc, msg = shardfunc_cp.shard_sql_insert(cur, cmd)
	if rc != 0:
		out.update({'Error': 'SQL insert command failed.'})
		out.update({'Error-detail': msg['Error']})
		conn.close()
		print('ERROR999999:  ' + repr(msg))
		sys.exit(12) # temp exit
	else:
		vmstat_write_count += 1

	# the sql-write loop is done, now commit
	cur.execute('commit;')
	# do not conn.close() until the end (or on error)
	out.update({'status': "OK"})
	print('vmstat write count: ' + str(vmstat_write_count))
#----------------------------------------------------------------------

# this test is not for GPL
rc, msg_d = mon_file("/var/natmsg/passwords.txt")
out.update(msg_d)

rslts = None
try:
	# Get the dictionary object from the file monitor:
	rslts= msg_d['mon_file']
except:
	print('I did not find a nonexistant key')

file_write_count = 0
if rslts is not None:
	for k, v in rslts.items():
		# There could be many files here
		fname = re.sub(r'[\'"\r\t\n]','', k[0:200])
		## print('k=' + str(k) + ' v=' + repr(v))
		# these are file attributes
		# file_type: inode: change_time: access_time: mod_time:
		cmd = 'INSERT INTO shardsvr.sysmon_file(file_name, file_type, ' \
			'inode, chg_time, access_time, mod_time, sysmon_file_dt ) ' \
			'VALUES(' + "'" + fname + "', " + str(v['file_type']) + ', ' \
			+	str(v['inode']) + ', '       +	str(v['change_time']) + ', ' \
			+	str(v['access_time']) + ', ' +	str(v['mod_time']) + ', ' \
			+ datestamp_sql + ');'

		rc, msg = shardfunc_cp.shard_sql_insert(cur, cmd)
		if rc != 0:
			out.update({'Error': 'SQL insert command failed.'})
			out.update({'Error-detail': msg['Error']})
			conn.close()
			print('ERROR33333:  ' + repr(msg))
			sys.exit(12) # temp exit
		else:
			file_write_count += 1

	# the sql-write loop is done, now commit
	cur.execute('commit;')
	# do not conn.close() until the end (or on error)
	out.update({'status': "OK"})
	print('file write count: ' + str(file_write_count))

# ----------------------------------------------------------------------
rc, msg_d = nstat()
out.update(msg_d)

try:
	# Get the dictionary object from the file monitor:
	rslts = msg_d['nstat']
except:
	print('I did not find the nstat dictionary key.')

if rslts is not None:
	v = rslts
	nstat_write_count = 0
	cmd = 'INSERT INTO shardsvr.sysmon_nstat(' + \
		'IpExtInOctets, IpExtOutOctets, ' + \
		'IpInReceives, TcpActiveOpens, TcpPassiveOpens, ' + \
		'IpOutRequests, sysmon_nstat_dt) ' + \
		'VALUES( ' \
		+  str(v['IpExtInOctets']) + ', '  \
		+	str(v['IpExtOutOctets']) + ', ' \
		+	str(v['IpInReceives']) + ', ' +  str(v['TcpActiveOpens']) + ', ' \
		+	str(v['TcpPassiveOpens']) + ', '  \
		+	str(v['IpOutRequests']) + ', '   \
		+ datestamp_sql + ');'
			
	rc, msg = shardfunc_cp.shard_sql_insert(cur, cmd)
	if rc != 0:
		out.update({'Error': 'SQL insert command failed.'})
		out.update({'Error-detail': msg['Error']})
		conn.close()
		print('ERROR8888:  ' + repr(msg))
		sys.exit(12) # temp exit
	else:
		nstat_write_count += 1

	# the sql-write loop is done, now commit
	cur.execute('commit;')
	# do not conn.close() until the end (or on error)
	out.update({'status': "OK"})
	print('nstat write count: ' + str(nstat_write_count))
				
# ----------------------------------------------------------------------
def main():
	global CONFIG_FNAME
	global MAIN_CONFIG
`	global DBNAME
`	global HOSTNAME
`	global DB_UNAME
`	global DB_PW

	MAIN_CONFIG = configparser.ConfigParser()

	MAIN_CONFIG.read(CONFIG_FNAME)

	DBNAME = MAIN_CONFIG['global']['DBNAME']
	HOSTNAME = MAIN_CONFIG['global']['HOSTNAME']
	DB_UNAME = MAIN_CONFIG['global']['DB_UNAME']
	DB_PW = MAIN_CONFIG['global']['DB_PW']


	if DBNAME == '' or DB_UNAME == '' or DB_PW == '' or HOSTNAME == '':
		print('Error, database connection details are missing.')
		sys.exti(15)

	ps_write_count = 0
	rc, msg_d = ps()
	try:
		# Get the dictionary object from the file monitor:
		rslts = msg_d['ps']
	except:
		print('I did not find a nonexistant key')

	if rslts is not None:
		for k, v in rslts.items():
			# The 'k' values here are numeric values
			# for the pid.
			# k=1046 v={'ppid': '1', 'uid': '0', 'time': '00:00:26', 
			# 'cmd': 'SCREEN', 'parms': ''}
			cmd = 'INSERT INTO shardsvr.sysmon_ps(' + \
				' ppid, uid, time, cmd, parms, sysmon_ps_dt) VALUES(' + \
				str(v['ppid']) + ', '  + \
				str(v['uid']) + ', ' + '0' + ', ' + \
				"'" + str(v['cmd']) + "', '" + str(v['parms']) + "', " + \
				datestamp_sql + ');'
					
			rc, msg = shardfunc_cp.shard_sql_insert(cur, cmd)
			if rc != 0:
				out.update({'Error': 'SQL insert command failed.'})
				out.update({'Error-detail': msg['Error']})
				conn.close()
				print('ERROR77777:  ' + repr(msg))
				sys.exit(12) # temp exit
			else:
				ps_write_count += 1

		# the sql-write loop is done, now commit
		cur.execute('commit;')
		# do not conn.close() until the end (or on error)
		out.update({'status': "OK"})
		print('ps write count: ' + str(ps_write_count))
					
		#----------------------------

		rec_counts_write_count = 0
		# Run the sysmon001 stored procedure to
		# capture a bunch of record counts and save
		# them to shardsvr.sysmon_rec_counts:
		cmd = 'SELECT shardsvr.sysmon001();'
		rc, my_data, msg = shardfunc_cp.shard_sql_select(cur, cmd)
		if rc != 0:
			out.update({'Error': 'SQL insert command failed.'})
			out.update({'Error-detail': msg['Error']})
			conn.close()
			print('ERROR111111:  ' + repr(msg))
			sys.exit(12) # temp exit
		else:
			rec_counts_write_count += 1

		print('rec_counts_write_count = ' + str(rec_counts_write_count))
	# --- - - -- - - 
	conn.close()
	#out.update(msg_d)
	##
	#print(json.dumps(out, indent=2))

if __name__ == '__main__':
	main()
