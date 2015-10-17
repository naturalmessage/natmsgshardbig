-- shard_expire_big.sql contains function shardsvrdb.shard_expire

-- This expires a shard, which means that the shard data
-- is deleted because it is too old.  The database record
-- will be retained for a while to prevent the Server Rewrite
-- attack (a malicious directory server could read the metadata,
-- readd all the shards, then rewrite to the same shards and
-- conceal that the original shards were burned).
--
-- A shard is marked as burned after it has been read.
-- A database record of a shard_id is removed after the
-- delete_db_entry_on_date date has passed.
--
-- Function:
-- 1) This function puts records into shardsvrdb.shard_kill_pending
--    table and sets the expire flag and other stuff for records
--    in the kill-pending list.
-- 2) A python job kills the shard files corresponding to the kill 
--    pending list and deletes all the records in that list.
-- ----------------------------------------
-- ----------------------------------------
-- ----------------------------------------
DROP FUNCTION IF EXISTS shardsvrdb.shard_big_expire();

CREATE FUNCTION shardsvrdb.shard_big_expire() RETURNS int AS $$
DECLARE
rows_expired int;
BEGIN
	-- Expiration sets  the expired attribute,
	-- and clear the expire date to hide information about the send date.
	-- ???? Note that the record will be obtained until the random
	-- date that was set in the delete_on_date field when the
	-- record was created.
	-- If the record was  expired, do nothing, because it
	-- has already been fixed

	INSERT INTO shardsvrdb.shard_big_kill_pending(big_shard_id, big_shard_pkid)
	select big_shard_id, big_shard_pkid from shardsvrdb.big_shards
	WHERE 
		burned = false
		and expired = false
		and expire_on_date < current_date;

	UPDATE shardsvrdb.big_shards
	SET 
		expired = true,
    expire_on_date = null
	WHERE 
		big_shard_pkid in (select big_shard_pkid from shardsvrdb.shard_big_kill_pending);

	GET DIAGNOSTICS rows_expired = ROW_COUNT;

	RETURN rows_expired;
END
$$
LANGUAGE 'plpgsql';

-- example:
-- select shardsvrdb.shard_expire('SID0000000101234567890bcdef0123456789abcdef01234567201408081942678857797');

