-- sysmon010.sql
--
-- This version is for shard servers as opposed 
-- to directory servers.  The schema is 'shardsvrdb'.
--
drop function IF EXISTS shardsvrdb.sysmon001();

CREATE FUNCTION shardsvrdb.sysmon001() RETURNS int
AS $$
DECLARE
tmp_int int;
rows_added int;
dt timestamp;
BEGIN
dt = current_timestamp;
INSERT INTO shardsvrdb.sysmon_rec_counts
	(
			big_shards               ,
			shards                   ,
			sysmon_rec_counts_dt
	)
	VALUES( 
    (select count(*) from shardsvrdb.big_shards), 
    (select count(*) from shardsvrdb.shards),
    dt
	);
	GET DIAGNOSTICS rows_added = ROW_COUNT;
	
	RETURN rows_added;
END	
$$
LANGUAGE 'plpgsql';

\df shardsvrdb.sysmon001
-- run it
--select shardsvrdb.sysmon001(13); 

--SELECT C.smd_id AS smd_id FROM shardsvrdb.smd_read_transactions AS B, shardsvrdb.smd_read_transaction_data AS C WHERE B.smd_read_pkid = 13 AND B.smd_read_pkid = C.smd_read_pkid;

