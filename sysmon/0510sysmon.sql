-- 0510sysmon.sql
--
-- This is the verion for shard servers as opposed to directory servers.
-- The schema for this version is shardsvr.
--
-- This script defines tables that will hold monitoring information
-- about a database.  Some of the information is about OS statistics
-- and some is about database stuff, like record counts.
--

CREATE TABLE IF NOT EXISTS  shardsvr.sysmon_processes(
	sysmon_processes_pkid       BIGSERIAL PRIMARY KEY,
	pid                         INT,
	run_time                    CHAR(10),
	uid                         INT,
	ppid                        INT,
	cmd                         VARCHAR(200),
	sysmon_processes_dt         TIMESTAMP NOT NULL

);
create index idx_sysmon_processes_pid on shardsvr.sysmon_processes(pid);
create index idx_sysmon_processes_dt on shardsvr.sysmon_processes(sysmon_processes_dt);


--
CREATE TABLE IF NOT EXISTS shardsvr.sysmon_file(
	sysmon_file_pkid       BIGSERIAL PRIMARY KEY,
	file_name              VARCHAR(200),
	file_type              INT,
	inode                  INT,
	chg_time               INT,
	access_time            INT,
	mod_time               INT,
	sysmon_file_dt         TIMESTAMP NOT NULL
);
create index idx_sysmon_file_file_name on shardsvr.sysmon_file(file_name);

--
CREATE TABLE IF NOT EXISTS shardsvr.sysmon_vmstat(
	sysmon_vmstat_pkid          BIGSERIAL PRIMARY KEY,
	K_total_memory              INT,
	K_used_memory               INT,
	K_active_memory             INT,
	K_free_memory               INT,
	K_swap_cache                INT,
	K_total_swap                INT,
	K_free_swap                 INT,
	non_nice_user_cpu_ticks     INT,
	nice_user_cpu_ticks         INT,
	system_cpu_ticks            INT,
	idle_cpu_ticks              INT,
	IO_wait_cpu_ticks           INT,
	boot_time                   INT,
	forks                       INT,
	sysmon_vmstat_dt            TIMESTAMP NOT NULL
);


CREATE TABLE IF NOT EXISTS  shardsvr.sysmon_nstat(
	sysmon_nstat_pkid           BIGSERIAL PRIMARY KEY,
	IpExtInOctets               INT,
	IpExtOutOctets              INT,
	IpInReceives                INT,
	TcpActiveOpens              INT,
	TcpPassiveOpens             INT,
	IpOutRequests               INT,
	TcpExtTCPOFOQueue           INT,
	sysmon_nstat_dt             TIMESTAMP NOT NULL
);
create index idx_sysmon_nstat_dt on shardsvr.sysmon_nstat(sysmon_nstat_dt);

--
CREATE TABLE IF NOT EXISTS shardsvr.sysmon_ps(
	sysmon_ps_pkid            BIGSERIAL PRIMARY KEY,
	ppid                      INT,
	uid                       INT,
	time                      INT,
	cmd                       VARCHAR(200),
	parms                     VARCHAR(200),
	sysmon_ps_dt              TIMESTAMP NOT NULL
);
create index idx_sysmon_ps_dt on shardsvr.sysmon_ps(sysmon_ps_dt);
--
CREATE TABLE IF NOT EXISTS shardsvr.sysmon_cpu(
	sysmon_cpu_pkid            BIGSERIAL PRIMARY KEY,
	cpu_wait                   INT,
	cpu_idle                   INT,
	cpu_user                   INT,
	cpu_nice                   INT,
	cpu_system                 INT,
	sysmon_cpu_dt              TIMESTAMP NOT NULL
);
create index idx_sysmon_cpu_dt on shardsvr.sysmon_cpu(sysmon_cpu_dt);

--
CREATE TABLE IF NOT EXISTS shardsvr.sysmon_rec_counts(
sysmon_rec_counts_pkid   BIGSERIAL PRIMARY KEY,
big_shards               BIGINT,
shards                   BIGINT,
sysmon_rec_counts_dt     TIMESTAMP
);
create index idx_sysmon_rec_counts_dt on shardsvr.sysmon_rec_counts(sysmon_rec_counts_dt);
--------------------------------------------------------------
--------------------------------------------------------------
--------------------------------------------------------------
--------------------------------------------------------------
--
GRANT USAGE, SELECT ON SEQUENCE shardsvr.sysmon_processes_sysmon_processes_pkid_seq  TO shardwebserver;
GRANT INSERT ON shardsvr.sysmon_processes TO shardwebserver;
GRANT UPDATE ON shardsvr.sysmon_processes TO shardwebserver;
GRANT SELECT ON shardsvr.sysmon_processes TO shardwebserver;
GRANT DELETE ON shardsvr.sysmon_processes TO shardwebserver;
--
GRANT USAGE, SELECT ON SEQUENCE shardsvr.sysmon_file_sysmon_file_pkid_seq  TO shardwebserver;
GRANT INSERT ON shardsvr.sysmon_file TO shardwebserver;
GRANT UPDATE ON shardsvr.sysmon_file TO shardwebserver;
GRANT SELECT ON shardsvr.sysmon_file TO shardwebserver;
GRANT DELETE ON shardsvr.sysmon_file TO shardwebserver;
--
GRANT USAGE, SELECT ON SEQUENCE shardsvr.sysmon_nstat_sysmon_nstat_pkid_seq  TO shardwebserver;
GRANT INSERT ON shardsvr.sysmon_nstat TO shardwebserver;
GRANT UPDATE ON shardsvr.sysmon_nstat TO shardwebserver;
GRANT SELECT ON shardsvr.sysmon_nstat TO shardwebserver;
GRANT DELETE ON shardsvr.sysmon_nstat TO shardwebserver;
--
GRANT USAGE, SELECT ON SEQUENCE shardsvr.sysmon_vmstat_sysmon_vmstat_pkid_seq  TO shardwebserver;
GRANT INSERT ON shardsvr.sysmon_vmstat TO shardwebserver;
GRANT UPDATE ON shardsvr.sysmon_vmstat TO shardwebserver;
GRANT SELECT ON shardsvr.sysmon_vmstat TO shardwebserver;
GRANT DELETE ON shardsvr.sysmon_vmstat TO shardwebserver;
--
GRANT USAGE, SELECT ON SEQUENCE shardsvr.sysmon_cpu_sysmon_cpu_pkid_seq  TO shardwebserver;
GRANT INSERT ON shardsvr.sysmon_cpu TO shardwebserver;
GRANT UPDATE ON shardsvr.sysmon_cpu TO shardwebserver;
GRANT SELECT ON shardsvr.sysmon_cpu TO shardwebserver;
GRANT DELETE ON shardsvr.sysmon_cpu TO shardwebserver;
--
--
GRANT USAGE, SELECT ON SEQUENCE shardsvr.sysmon_ps_sysmon_ps_pkid_seq  TO shardwebserver;
GRANT INSERT ON shardsvr.sysmon_ps TO shardwebserver;
GRANT UPDATE ON shardsvr.sysmon_ps TO shardwebserver;
GRANT SELECT ON shardsvr.sysmon_ps TO shardwebserver;
GRANT DELETE ON shardsvr.sysmon_ps TO shardwebserver;

--
GRANT USAGE, SELECT ON SEQUENCE shardsvr.sysmon_rec_counts_sysmon_rec_counts_pkid_seq  TO shardwebserver;
GRANT INSERT ON shardsvr.sysmon_rec_counts TO shardwebserver;
GRANT UPDATE ON shardsvr.sysmon_rec_counts TO shardwebserver;
GRANT SELECT ON shardsvr.sysmon_rec_counts TO shardwebserver;
GRANT DELETE ON shardsvr.sysmon_rec_counts TO shardwebserver;

-- show the tables
--\dt shardsvr.*

--show permissions for the shard tables
--\dp shardsvr.*

