-- shard_expire.sql contains function shardsvrdb.shard_expire

-- This expires a shard, it does not perform 'delete/burn' of the shard data.
-- A shard 'expires' when the time has run out and it has not been read.
-- A shard is deleted (burned) after it has been read.
--
-- ----------------------------------------
-- ----------------------------------------
-- ----------------------------------------
DROP FUNCTION IF EXISTS shardsvrdb.shard_expire();

CREATE FUNCTION shardsvrdb.shard_expire() RETURNS int AS $$
DECLARE
rows_expired int;
BEGIN
	-- Expiration sets  the expired attribute,
	-- clears the shard value with hex zeroes,
	-- and clear the expire date to hide information about the send date.
	-- Note that the record will be obtained until the random
	-- date that was set in the delete_on_date field when the
	-- record was created.
	-- If the record was  expired, do nothing, because it
	-- has already been fixed
	UPDATE shardsvrdb.shards
	SET 
    shard = '\x0000000000000000000000000000000000000000',
		expired = true,
    expire_on_date = null
	WHERE 
		burned = false
		and expired = false
		and expire_on_date < current_date;

	GET DIAGNOSTICS rows_expired = ROW_COUNT;

	RETURN rows_expired;
END
$$
LANGUAGE 'plpgsql';

-- example:
-- select shardsvrdb.shard_expire('SID0000000101234567890bcdef0123456789abcdef01234567201408081942678857797');

