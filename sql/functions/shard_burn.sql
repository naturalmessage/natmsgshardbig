-- shard_burn.sql contains function shardsvrdb.shard_burn

-- This performs 'delete/burn' of the shard data, but does not 'expire' it.
-- A shard 'expires' when the time has run out and it has not been read.
-- A shard is deleted (burned) after it has been read.
--
-- ----------------------------------------
-- ----------------------------------------
-- ----------------------------------------
DROP FUNCTION IF EXISTS shardsvrdb.shard_burn(char(35));

CREATE FUNCTION shardsvrdb.shard_burn(selected_shard_id char(35)) RETURNS int AS $$
DECLARE
rows_burned int;
BEGIN
	-- Deletion will set the 'burned' attribute,
	-- clear the shard value with hex zeroes,
	-- and clear the expire date to hide information about the send date.
	-- Note that the record will be obtained until the random
	-- date that was set in the delete_on_date field when the
	-- record was created.
	-- If the record was  expired, do nothing, because it
	-- has already been fixed
	UPDATE shardsvrdb.shards
	SET 
    shard = '\x0000000000000000000000000000000000000000',
		burned = true,
    expire_on_date = null
	WHERE shard_id = selected_shard_id and expired = false;

	GET DIAGNOSTICS rows_burned = ROW_COUNT;

	RETURN rows_burned;
END
$$
LANGUAGE 'plpgsql';
--
--select shardsvrdb.shard_burn('SID0000000101234567890bcdef0123456789abcdef01234567201408081942678857797');

