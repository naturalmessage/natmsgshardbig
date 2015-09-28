#!/bin/env python3
# shard_housekeeping.py
#
# Update the db password below, then...
# This should be run like this:
#    sudo -u natmsg shard_housekeeping.py
# or put in a crontab like this:
#    sudo -u natmsg crontab -e
# and put lines like this into the crontab:
#    * 2 * * * /usr/bin/python3 /home/natmsg/python/shard_housekeeping.py
#    */5 * * * * /usr/bin/python3 /home/natmsg/python/monitor.py


# This will call a stored procedure/'PostgreSQL user function'
# to identify and flag shards that have expired,
# then this python script will remove those shard files.
# and also delete old shard records from the database.

# import subprocess
# import re
import sys
import os
import datetime
import psycopg2
import shardfunc_cp


shard_dir = '/var/natmsg/shards'
# the psql user names are in lower case
#hostname = '213.211.150.141'
HOSTNAME = '127.0.0.1'
DBNAME = 'sharddbsvr'
UNAME = 'shardwebserver'
PW = 'YOUR_DB_PASSWORD_HERE'

###############################################################################
datestamp = datetime.datetime.now()
datestamp_sql = "'" + str(datestamp.year) + "-" \
    + str(datestamp.month).zfill(2) + \
    "-"  + str(datestamp.day).zfill(2) + ' ' \
    + str(datestamp.hour).zfill(2) + ':' + \
    str(datestamp.minute).zfill(2) + ':' \
    + str(datestamp.second).zfill(2) +  "'::timestamp "

# Register the ssl keys and a few shards that
# I create that should never be read.
out = {}
conn_str = "host=" + HOSTNAME + " dbname=" + DBNAME + " user=" + UNAME \
    + " password='" + PW + "'"
try:
    conn = psycopg2.connect(conn_str)
except(TypeError):
    out.update({'Error': 'There was a data type error when trying to connect '
        + 'to the PostgreSQL database.'})
    sys.exit(12) # temp exit
except(psycopg2.ProgrammingError):
    out.update({'Error': 'Could not connect to the PostgreSQL server.  Did '
        + 'the admin restart the postgre server?'})
    sys.exit(12) # temp exit
except:
    out.update({'Error': 'Some other type of error during conneciton to the '
        + 'PostgreSQL database.'})
    sys.exit(12) # temp

cur = conn.cursor()
#------------------------------------------------------------
#  PART I. RUN A STORED PROCEDURE/'USER FUNCTION' TO
#  IDENTIFY THE SHARDS TO EXPIRE.


# When I run this stored procedure, it will
# identify shards that need to be delete,
# it will flag the shards as expired,
# and it will put the list of shardsin
# shard.shard_big_kill_pending table.
cmd = 'SELECT shard.shard_big_expire();'
my_data = None

rc, my_data, msg = shardfunc_cp.shard_sql_select(cur, cmd)
if rc != 0:
    out.update({'Error': 'SQL insert command failed.'})
    out.update({'Error-detail': msg['Error']})
    conn.close()
    print('ERROR 111:  ' + repr(msg))
    sys.exit(12) # temp exit

if my_data[0][0] == 0:
    print('WARNING. The scan for expired shards found nothing.')

#------------------------------------------------------------
#  PART II. DELETE THE SHARD FILES FROM DISK

cmd = 'SELECT big_shard_id from shard.shard_big_kill_pending;'
my_data = None

rc, my_data, msg = shardfunc_cp.shard_sql_select(cur, cmd)
if rc != 0:
    out.update({'Error': 'SQL insert command failed.'})
    out.update({'Error-detail': msg['Error']})
    conn.close()
    print('ERROR 888:  ' + repr(msg))
    sys.exit(12) # temp exit

print('TEST shard id list: ' + repr(my_data))

failed_del_list = []
removed_file_count = 0
for row_dat in my_data:
    shard_id = row_dat[0]
    fname = shard_dir + '/%s' % (shard_id.strip())
    ## print('removing this file: ' + fname)
    try:
        os.remove(fname)
    except:
        failed_del_list.append(fname)
        print(sys.exc_info())
        continue

    removed_file_count += 1


print('I removed ' + str(removed_file_count) + ' shard files.')
print('==== list of failed deletes: ' + repr(failed_del_list))

#------------------------------------------------------------
#  PART III. DELETE RECRODS FROM THE shard_big_kill_pending
#                         TRANSACTION TABLE.
# -- Now kill all the records in shard_big_expire
cmd = 'DELETE FROM shard.shard_big_kill_pending;'
my_data = None

rc, my_data, msg = shardfunc_cp.shard_sql_select(cur, cmd)
if rc != 0:
    out.update({'Error': 'SQL insert command failed.'})
    out.update({'Error-detail': msg['Error']})
    conn.close()
    print('ERROR 777:  ' + repr(msg))
    sys.exit(12) # temp exit

# the sql-write loop is done, now commit
cur.execute('commit;')
# do not conn.close() until the end (or on error)


#------------------------------------------------------------
#                        PART IV: EXPIRE LITTLE SHARDS
# (these shards are in the database)
cmd = 'SELECT shard.shard_expire();'
my_data = None

rc, my_data, msg = shardfunc_cp.shard_sql_select(cur, cmd)
if rc != 0:
    out.update({'Error': 'SQL insert command failed.'})
    out.update({'Error-detail': msg['Error']})
    conn.close()
    print('ERROR 666:  ' + repr(msg))
    sys.exit(12) # temp exit

if my_data[0][0] == 0:
    print('WARNING. The scan for expired shards found nothing.')
else:
    print('I expired ' + str(my_data[0][0]) + ' little shards')

#------------------------------------------------------------
#                 PART V: DELETE DATABASE RECORDS OF SHARDS
#(This removes the database entries that hold old shard IDs--
# remember that the actual shards are delted within about 
# 5 days of creation, and only the record of the shard ID
# remains to prevent recreating the same shard).

cmd = 'SELECT shard.shard_delete_db_entries();'
my_data = None

rc, my_data, msg = shardfunc_cp.shard_sql_select(cur, cmd)
if rc != 0:
    out.update({'Error': 'SQL insert command failed.'})
    out.update({'Error-detail': msg['Error']})
    conn.close()
    print('ERROR 555:  ' + repr(msg))
    sys.exit(12) # temp exit

if my_data[0][0] == 0:
    print('WARNING. The scan for deletable shards found nothing.')
else:
    print('I deleted ' + str(my_data[0][0]) + ' shards database records')
#------------------------------------------------------------
conn.close()
