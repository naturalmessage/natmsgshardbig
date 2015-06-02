-- shard_delete.sql contains function shardsvr.shard_delete_db-entries(),
-- which is used to remove database entries about 20 days they are created.
--
-- The main shard data will have been delete already, but the database
-- records are retained for a while to to prevent teh Server Rewrite
-- attack in which the server reads all the shard and rewrites
-- them before making them available to the recipient (the shard
-- servers block this by not allowing an existing, deleted, or expired
-- shard to be rewritten.

--
-- ----------------------------------------
-- ----------------------------------------
-- ----------------------------------------
DROP FUNCTION IF EXISTS shardsvr.shard_delete_db_entries();

CREATE FUNCTION shardsvr.shard_delete_db_entries() RETURNS 
TABLE (little_rows_deleted int, big_rows_deleted int)
AS $$
DECLARE
little_rows_deleted int;
big_rows_deleted int;
BEGIN

	DELETE FROM shardsvr.shards
	WHERE 
		delete_db_entry_on_date < current_date;

	GET DIAGNOSTICS little_rows_deleted = ROW_COUNT;

	--
	DELETE FROM shardsvr.big_shards
	WHERE 
		delete_db_entry_on_date < current_date;

	GET DIAGNOSTICS big_rows_deleted = ROW_COUNT;

	RETURN QUERY
	SELECT little_rows_deleted, big_rows_deleted;
END
$$
LANGUAGE 'plpgsql';

-- example:
-- select shardsvr.shard_expire('SID0000000101234567890bcdef0123456789abcdef01234567201408081942678857797');

