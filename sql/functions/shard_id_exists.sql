-- shard_id_exists.sql
-- This will define a stored procedure to 
-- check if a shard_id exists (to protect against
-- a shard-rewrite attack).  This currently
-- needs to check two tables, but will eventually
-- need to check only one after I unify the process.

drop function IF EXISTS shardsvrdb.shard_id_exists(char(35));

CREATE FUNCTION shardsvrdb.shard_id_exists(selected_shard_id char(35)) RETURNS boolean
AS $$
DECLARE
tmp_int int;
rows_check int;
BEGIN
  rows_check = 0;

  PERFORM shard_id from shardsvrdb.shards where shard_id = selected_shard_id;
  GET DIAGNOSTICS rows_check = ROW_COUNT;

  IF rows_check > 0 THEN
  	RETURN TRUE;
	END IF;
  -- 
  
  rows_check = 0;
  PERFORM big_shard_id from shardsvrdb.big_shards where big_shard_id = selected_shard_id;
  GET DIAGNOSTICS rows_check = ROW_COUNT;

  IF rows_check > 0 THEN
  	RETURN TRUE;
	END IF;
  
  RETURN FALSE;
END	
$$
LANGUAGE 'plpgsql';

\df shardsvrdb.shard_id_exists
-- run it
--select shardsvrdb.test_return(13); 

--SELECT C.smd_id AS smd_id FROM shardsvrdb.smd_read_transactions AS B, shardsvrdb.smd_read_transaction_data AS C WHERE B.smd_read_pkid = 13 AND B.smd_read_pkid = C.smd_read_pkid;

