-- scan_shard_delete.sql 
-- This contains function shard.scan_shard_delete,
-- which will identify all shards that are passed their retention date
-- and delete them by removing the entire shard record.
-- This should be run via a cron job.

--
-- ----------------------------------------
-- ----------------------------------------
-- ----------------------------------------
DROP FUNCTION IF EXISTS shardsvr.scan_shard_delete();

CREATE FUNCTION shardsvr.scan_shard_delete() RETURNS int AS $$
DECLARE
rows_deleted int;
BEGIN
	-- I delete only when the 'delete_on_date' has passed, in art
	-- because of imprecision from GMT conversion or lack thereof.

	DELETE FROM shardsvr.shards WHERE delete_on_date < current_date;

	GET DIAGNOSTICS rows_deleted = ROW_COUNT;

	RETURN rows_deleted;
END
$$
LANGUAGE 'plpgsql';
--

