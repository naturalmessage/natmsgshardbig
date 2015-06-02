-- shard_burn_big.sql contains function shardsvr.shard_burn_big

-- This performs 'burn' of the shard data,, which means
-- that any record of the content of the shard is erased.
-- but the database record is retained for a couple weeks to
-- prevent people from overwriting this shard and to notify
-- people that the shard has been burned.
-- A shard 'expires' when the time has run out and it has not been read.
-- A shard is burned after it has been read.
--
-- ----------------------------------------
-- ----------------------------------------
-- ----------------------------------------
DROP FUNCTION IF EXISTS shardsvr.shard_burn_big(char(35));

CREATE FUNCTION shardsvr.shard_burn_big(selected_shard_id char(35)) RETURNS int AS $$
DECLARE
rows_burned int;
BEGIN
	-- This porcess will set the 'burned' attribute,
	-- and clear the expire date to hide information about the send date
	-- (which might be futile now that shards are stored by day
	-- in the directory tree).
	-- Note that the record will be obtained until the random
	-- date that was set in the delete_on_date field when the
	-- record was created.
	-- If the record was  expired, do nothing, because it
	-- has already been fixed
	UPDATE shardsvr.big_shards
	SET 
		burned = true,
    expire_on_date = null
	WHERE big_shard_id = selected_shard_id and expired = false;

	GET DIAGNOSTICS rows_burned = ROW_COUNT;

	RETURN rows_burned;
END
$$
LANGUAGE 'plpgsql';
--

