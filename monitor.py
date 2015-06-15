#!/usr/local/bin/python3
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


# This will eventually monitor system resources
# and send the info to a database.

import configparser
import datetime
import json
import psycopg2
import re
import shardfunc_cp as shardfuncs
import subprocess
import sys

CONFIG_FNAME = '/var/natmsg/conf/housekeeping_shardsvr.conf'
MAIN_CONFIG = None

# The psql user names are in lower case
HOSTNAME = ''
DBNAME = ''
UNAME = 'shardwebserver'
PW = ''
CONN_STR = ''
MON_FILE_LIST = []


datestamp = datetime.datetime.now()
datestamp_sql = "'" + str(datestamp.year) + '-' \
    + str(datestamp.month).zfill(2)  \
    + '-' + str(datestamp.day).zfill(2) + ' ' \
    + str(datestamp.hour).zfill(2) + ':' \
    + str(datestamp.minute).zfill(2) + ':' \
    + str(datestamp.second).zfill(2) + "'::timestamp "
print('datestamp: ' + datestamp_sql)


###############################################################################
def mon_file(fname):
    """Monitor some file statistics."""
    global MON_FILE_LIST

    file_info = []

    rc = 0
    out = {}
    cmd_lst = [
        'stat',
        '-c',
        '{"%n": {"inode": %i, "access_time": %X, '
        + '"mod_time": %Y, "change_time": %Z, "file_type": %T }}',
        fname]

    p = None
    p = subprocess.Popen(cmd_lst, stdout=subprocess.PIPE)
    if p is None:
        out.update({'Error': 'Subprocess for stat command failed.'})
        rc = 12
        return((rc, {"mon_file": out}))

    try:
        rslt = p.communicate()[0].decode('utf-8')
    except Exception:
        out.update(
            {
                'Error': 'Failed to initiate '
                + 'the process for the stat command.'})
        rc = 12
        return((rc, {"mon_file": out}))

    try:
        file_info_json = json.loads(rslt)
    except Exception:
        print('Error executing the subprocess command for stat.')
        print('Filename was ' + fname)
        return(12)

    out.update(file_info_json)

    return((rc, {"mon_file": out}))


# #
# # The file layout for 'cpu' lines in /proc/stat (CentOS 6)
# # * user: normal processes executing in user mode
# # * nice: niced processes executing in user mode
# # * system: processes executing in kernel mode
# # * idle: twiddling thumbs
# # * iowait: waiting for I/O to complete
# # * irq: servicing interrupts
# # * softirq: servicing softirqs
#
#
def nstat():
    """Run the nstat program and log some information

    This will collect information about input and output
    bandwidth, TCP connections, and number of requests.
    """
    rc = 0
    out = {}

    # CentOS 6 does not support -j for nstat
    cmd_lst = ['nstat', '-az']

    p = None
    p = subprocess.Popen(cmd_lst, stdout=subprocess.PIPE)
    if p is None:
        out.update({'Error': 'Subprocess for stat command failed.'})
        rc = 12
        return((rc, {"nstat": out}))

    try:
        rslt = p.communicate()[0].decode('utf-8')
    except Exception:
        out.update(
            {
                'Error': 'Failed to initiate the process for '
                + 'the nstat command.'})
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
        if flds[0] in (
                'IpExtInOctets',
                'IpExtOutOctets',
                'IpInReceives',
                'TcpActiveOpens',
                'TcpPassiveOpens',
                'IpOutRequests'):
            # I found a key value of interest, so save the info
            out.update({flds[0]: flds[1]})

    return((rc, {"nstat": out}))


###############################################################################
def ps():
    """Log information about running processes"""
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
    except Exception:
        out.update(
            {
                'Error': 'Failed to initiate the '
                + 'process for the ps command.'})
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
            my_cmd = re.sub(r'[\'"\r\t\n]', '', flds[4][0:200])
            my_parms = ''
            if len(flds) > 5:
                # The next line takes the list of program parmaters
                # that appear in teh extended ps listing, and retains
                # only  the essential chars that could not cause sql injection
                # or other problems.
                my_parms = re.sub(
                    r'[^a-zA-Z \t0-9]',
                    '',
                    ' '.join(flds[5:])[0:200])

            out.update(
                {
                    flds[1]: {
                        'uid': flds[0],
                        'ppid': flds[2],
                        'time': flds[3],
                        'cmd': my_cmd,
                        'parms': my_parms}})
        else:
            past_header = True
            pass  # skip the first row of data -- it is the ps output header.

    return((rc, {"ps": out}))


###############################################################################
def vmstat():
    """Log vmstat information about memory and CPU."""
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
    except Exception:
        out.update({'Error': 'Failed to initiate the process '
                    + 'for the vmstat command.'})
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

        if k in (
                'K_total_memory',
                'K_used_memory',
                'K_active_memory',
                'K_free_memory',
                'K_swap_cache',
                'K_total_swap',
                'K_free_swap',
                'non-nice_user_cpu_ticks',
                'nice_user_cpu_ticks',
                'system_cpu_ticks',
                'idle_cpu_ticks',
                'IO-wait_cpu_ticks',
                'boot_time',
                'forks'):
            out.update({k: v})

    return((rc, {"vmstat": out}))


###############################################################################
def main():
    """Run multiple routines to log system info.

    * Run the ps routine to get information about active
      processes (and log it to the database),
    * Run the symon001 stored procedure to get various
      record counts (and log it to the databse),
    * Run vmstat and save memory and CPU info,
    * Collect and log information of files that have been accessed,
    * Collect and log nstat data for network IO.
    """

    global CONFIG_FNAME
    global MAIN_CONFIG
    global DBNAME
    global HOSTNAME
    global DB_UNAME
    global DB_PW
    global CONN_STR
    global MON_FILE_LIST

    out = {}

    MAIN_CONFIG = configparser.ConfigParser()
    MAIN_CONFIG.read(CONFIG_FNAME)

    DBNAME = MAIN_CONFIG['global']['DBNAME']
    HOSTNAME = MAIN_CONFIG['global']['HOSTNAME']
    DB_UNAME = MAIN_CONFIG['global']['DB_UNAME']
    DB_PW = MAIN_CONFIG['global']['DB_PW']

    
    CONN_STR = "host=" + HOSTNAME + " dbname=" + DBNAME + " user=" \
            + DB_UNAME + " password='" + DB_PW + "'"

    if 'MON_FILE_LIST' in MAIN_CONFIG['global']:
        MON_FILE_LIST = MAIN_CONFIG['global']['MON_FILE_LIST']
    else:
        MON_FILE_LIST= []

    if DBNAME == '' or DB_UNAME == '' or DB_PW == '' or HOSTNAME == '':
        print('Error, database connection details are missing.')
        sys.exti(15)
    # -------------------------------------------------------------------------
    conn, msg_d = shardfuncs.shard_connect(CONN_STR)
    if conn is None:
        print(shardfuncs.safe_string(msg_d))
        raise RuntimeError(shardfuncs.err_log(110015, 'Failed to '
            + 'make a database connection in '
            + 'nm_db_table_names', extra_msg=msg_d))
    
    cur = conn.cursor()
    # -------------------------------------------------------------------------
    ps_write_count = 0
    rc, msg_d = ps()
    try:
        # Get the dictionary object from the file monitor:
        rslts = msg_d['ps']
    except Exception:
        print('I did not find a nonexistant key')

    if rslts is not None:
        for k, v in rslts.items():
            # The 'k' values here are numeric values
            # for the pid.
            # k=1046 v={'ppid': '1', 'uid': '0', 'time': '00:00:26',
            # 'cmd': 'SCREEN', 'parms': ''}
            cmd = 'INSERT INTO shardsvr.sysmon_ps(' + \
                ' ppid, uid, time, cmd, parms, sysmon_ps_dt) VALUES(' + \
                str(v['ppid']) + ', ' + \
                str(v['uid']) + ', ' + '0' + ', ' + \
                "'" + str(v['cmd']) + "', '" + str(v['parms']) + "', " + \
                datestamp_sql + ');'

            rc, msg = shardfuncs.shard_sql_insert(cur, cmd)
            if rc != 0:
                out.update({'Error': 'SQL insert command failed.'})
                out.update({'Error-detail': msg['Error']})
                conn.close()
                print('ERROR77777:  ' + repr(msg))
            else:
                ps_write_count += 1

        # the sql-write loop is done, now commit
        cur.execute('commit;')
        # do not conn.close() until the end (or on error)
        out.update({'status': "OK"})
        print('ps write count: ' + str(ps_write_count))

    # -------------------------------------------------------------------------
    #       sysmon001: stored procedure to get table counts
    #
    rec_counts_write_count = 0
    # Run the sysmon001 stored procedure to
    # capture a bunch of record counts and save
    # them to shardsvr.sysmon_rec_counts:
    cmd = 'SELECT shardsvr.sysmon001();'
    rc, my_data, msg = shardfuncs.shard_sql_select(cur, cmd)
    if rc != 0:
        out.update({'Error': 'SQL insert command failed.'})
        out.update({'Error-detail': msg['Error']})
        conn.close()
        print('ERROR111111:  ' + repr(msg))
    else:
        rec_counts_write_count += 1

    print('rec_counts_write_count = ' + str(rec_counts_write_count))

    # -------------------------------------------------------------------------
    #                 vmstat - collect memory and CPU info
    #
    rc, msg_d = vmstat()
    out.update(msg_d)
    rslts = None
    vmstat_write_count = 0
    try:
        # Get the dictionary object from the file monitor:
        rslts = msg_d['vmstat']
    except Exception:
        print('Error. I did not find vmstat output.')

    if rslts is not None:
        v = rslts
        # Note: two table fields have '-' replaced with '_':
        # non-nice_user_cpu_ticks and IO-wait_cpu_ticks
        cmd = 'INSERT INTO shardsvr.sysmon_vmstat (' \
            + 'K_total_memory, K_used_memory, K_active_memory, ' \
            + 'K_free_memory, K_swap_cache, ' \
            + 'K_total_swap, K_free_swap, ' \
            + 'non_nice_user_cpu_ticks, nice_user_cpu_ticks, ' \
            + 'system_cpu_ticks, idle_cpu_ticks, IO_wait_cpu_ticks, ' \
            + 'boot_time, sysmon_vmstat_dt) ' \
            + 'VALUES (' + str(v['K_total_memory']) + ', ' \
            + str(v['K_used_memory']) + ', ' \
            + str(v['K_active_memory']) + ', ' \
            + str(v['K_free_memory']) + ', ' \
            + str(v['K_swap_cache']) + ', ' \
            + str(v['K_total_swap']) + ', ' \
            + str(v['K_free_swap']) + ', ' \
            + str(v['non-nice_user_cpu_ticks']) + ', ' \
            + str(v['nice_user_cpu_ticks']) + ', ' \
            + str(v['system_cpu_ticks']) + ', ' \
            + str(v['idle_cpu_ticks']) + ', ' \
            + str(v['IO-wait_cpu_ticks']) + ', ' \
            + str(v['boot_time']) + ', ' + datestamp_sql + ');'

        rc, msg = shardfuncs.shard_sql_insert(cur, cmd)
        if rc != 0:
            out.update({'Error': 'SQL insert command failed.'})
            out.update({'Error-detail': msg['Error']})
            conn.close()
            print('ERROR999999:  ' + repr(msg))
        else:
            vmstat_write_count += 1

        # the sql-write loop is done, now commit
        cur.execute('commit;')
        # do not conn.close() until the end (or on error)
        out.update({'status': "OK"})
        print('vmstat write count: ' + str(vmstat_write_count))
    # -------------------------------------------------------------------------
    #                        File Monior
    #
    #  (collect file attributes for specific files)
    #
    if len(MON_FILE_LIST) > 0:
        for fname in MON_FILE_LIST:
            rc, msg_d = mon_file(fname)
            out.update(msg_d)

            rslts = None
            try:
                # Get the dictionary object from the file monitor:
                rslts = msg_d['mon_file']
            except Exception:
                print('I did not find results from the file_monitor.')

            file_write_count = 0
            if rslts is not None:
                for k, v in rslts.items():
                    # There could be many files here
                    fname = re.sub(r'[\'"\r\t\n]', '', k[0:200])

                    # These are file attributes
                    # file_type, inode, change_time,
                    # access_time, mod_time.
                    cmd = 'INSERT INTO shardsvr.sysmon_file(' \
                        'file_name, file_type, ' \
                        'inode, chg_time, access_time, ' \
                        'mod_time, sysmon_file_dt ) ' \
                        'VALUES(' + "'" + fname + "', " \
                        + str(v['file_type']) + ', ' \
                        + str(v['inode']) + ', ' \
                        + str(v['change_time']) + ', ' \
                        + str(v['access_time']) + ', ' \
                        + str(v['mod_time']) + ', ' \
                        + datestamp_sql + ');'

                    rc, msg = shardfuncs.shard_sql_insert(cur, cmd)
                    if rc != 0:
                        out.update({'Error': 'SQL insert command failed.'})
                        out.update({'Error-detail': msg['Error']})
                        conn.close()
                        print('ERROR33333:  ' + repr(msg))
                    else:
                        file_write_count += 1

            # the sql-write loop is done, now commit
            cur.execute('commit;')
        # do not conn.close() until the end (or on error)
        out.update({'status': "OK"})
        print('file write count: ' + str(file_write_count))

    # -------------------------------------------------------------------------
    #                nstat - Network IO stats
    #
    rc, msg_d = nstat()
    out.update(msg_d)

    try:
        # Get the dictionary object from the file monitor:
        rslts = msg_d['nstat']
    except Exception:
        print('I did not find the nstat dictionary key.')

    if rslts is not None:
        v = rslts
        nstat_write_count = 0
        cmd = 'INSERT INTO shardsvr.sysmon_nstat(' + \
            'IpExtInOctets, IpExtOutOctets, ' + \
            'IpInReceives, TcpActiveOpens, TcpPassiveOpens, ' + \
            'IpOutRequests, sysmon_nstat_dt) ' + \
            'VALUES( ' \
            + str(v['IpExtInOctets']) + ', '  \
            + str(v['IpExtOutOctets']) + ', ' \
            + str(v['IpInReceives']) + ', ' + str(v['TcpActiveOpens']) + ', ' \
            + str(v['TcpPassiveOpens']) + ', ' \
            + str(v['IpOutRequests']) + ', ' \
            + datestamp_sql + ');'

        rc, msg = shardfunc.shard_sql_insert(cur, cmd)
        if rc != 0:
            out.update({'Error': 'SQL insert command failed.'})
            out.update({'Error-detail': msg['Error']})
            conn.close()
            print('ERROR8888:  ' + repr(msg))
        else:
            nstat_write_count += 1

        # the sql-write loop is done, now commit
        cur.execute('commit;')
        # do not conn.close() until the end (or on error)
        out.update({'status': "OK"})
        print('nstat write count: ' + str(nstat_write_count))


if __name__ == '__main__':
    main()
