-- sysmon010.sql
--
-- This version is for shard servers as opposed 
-- to directory servers.  The schema is 'shardsvr'.
--
drop function IF EXISTS shardsvr.sysmon001();

CREATE FUNCTION shardsvr.sysmon001() RETURNS int
AS $$
DECLARE
tmp_int int;
rows_added int;
dt timestamp;
BEGIN
dt = current_timestamp;
INSERT INTO shardsvr.sysmon_rec_counts
	(
			big_shards               ,
			shards                   ,
			sysmon_rec_counts_dt
	)
	VALUES( 
    (select count(*) from shardsvr.big_shards), 
    (select count(*) from shardsvr.shards),
    dt
	);
	GET DIAGNOSTICS rows_added = ROW_COUNT;
	
	RETURN rows_added;
END	
$$
LANGUAGE 'plpgsql';

\df shardsvr.sysmon001
-- run it
--select shardsvr.sysmon001(13); 

--SELECT C.smd_id AS smd_id FROM shardsvr.smd_read_transactions AS B, shardsvr.smd_read_transaction_data AS C WHERE B.smd_read_pkid = 13 AND B.smd_read_pkid = C.smd_read_pkid;

