# Python 3: ArchiveNM.py
#  Function:
#  This will collect the files in /home/postgres that
#  need to be sent to a new Natural Message machine 
#  that is being initialized.  This currently grabs
#  directory server and shard server files.
#  It can also be used as an archiver.

import datetime
import tarfile
import os
import sys

# For the version code, enter the format used 
# in the naturalmsg_svr_#_#_#.py files
test_or_prod = 'prod'
version = '0_0_5' 
DSTAMP = datetime.datetime.now().strftime('%Y%m%d%H%M%S')

# (do not add a trailing slash on directory names)
pgm_dir = '/var/natmsg'
sql_dir = '/home/postgres/shard/sql/' + test_or_prod
function_dir = '/home/postgres/shard/sql/' + test_or_prod + '/functions'

pgm_files = ('naturalmsg-svr' + version  + '.py',
	'shardfunc_cp' + version + '.py')

sql_files = ( \
	'0001create_db.sh', 
	'0002create_tables.sql', 
	'0005shardserver.sql', 
	'0007shardbig.sql', 
	'0020payment.sql', 
	'0500sysmon.sql', 
	'blog01.sql' \
)
function_files = ( \
  'nm_blog_entry_newest.sql',
  'read_inbasket_stage010.sql',
  'read_inbasket_stage020.sql',
  'read_inbasket_stage030.sql',
  'scan_shard_delete.sql',
  'shard_burn.sql',
  'shard_delete_db_entries.sql',
  'shard_delete.sql',
  'shard_expire_big.sql',
  'shard_expire.sql',
  'shard_id_exists.sql',
  'smd_create0010.sql',
  'sysmon001.sql' \
)


tar_fname_base = 'NatMsgSQLArchive' + version
tar_fname = tar_fname_base + '.tar'
if os.path.isfile(tar_fname):
	# The tar file already exists, rename it
	try:
		os.renames(tar_fname, tar_fname_base + '-' + DSTAMP + '.tar')
	except:
		print('Error renaming an existing tar file: ' + tar_fname)
		print('Maybe you do not have permission.')
		sys.exit(12)

t = tarfile.TarFile(tar_fname, mode='w')

for f in pgm_files:
	# the full path is already specified in the file list.
	t.add(os.path.normpath(pgm_dir + '/' + f))


for f in sql_files:
	t.add(os.path.normpath(sql_dir + '/' + f))

for f in function_files:
	t.add(os.path.normpath(function_dir + '/' + f))

t.close()
