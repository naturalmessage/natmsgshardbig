-- 0016 big shard

-- ++++++++++++++++++++++++++++++++++++++++++++++++
-- This is for big shard servers that might hold
-- multi-megabyte shards.
--
-- I will eventually activate 
-- the constraint to set the max size on the shardsvrdb.shards.
--
-- The 'retention minutes' field will facilitate chat 
-- in thefuture,but iti is not used now.
--
-- Note that I do not store the original name of the file that was uploaded.
--
--drop table shardsvrdb.shards;
CREATE TABLE IF NOT EXISTS shardsvrdb.big_shards(
big_shard_pkid           BIGSERIAL PRIMARY KEY,
big_shard_id             CHAR(35) NOT NULL,
retention_minutes        INT NOT NULL DEFAULT 0,
expire_on_date           DATE DEFAULT current_date + 5,
delete_db_entry_on_date  DATE DEFAULT current_date + 20,
burned                   BOOLEAN DEFAULT false,
expired                  BOOLEAN DEFAULT false,
encryption_format        INT DEFAULT 0,
day_code                 char(1) DEFAULT ' '
);
create unique index idx_big_shard_id on shardsvrdb.big_shards(big_shard_id);


--
CREATE TABLE IF NOT EXISTS shardsvrdb.shard_big_kill_pending(
shard_big_kill_pending_pkid  BIGSERIAL PRIMARY KEY,
big_shard_pkid               INT,
big_shard_id                CHAR(35)
);
--++++++++++++++++++++++++++++++++++++++++++++
--++++++++++++++++++++++++++++++++++++++++++++
--++++++++++++++++++++++++++++++++++++++++++++
--++++++++++++++++++++++++++++++++++++++++++++
--++++++++++++++++++++++++++++++++++++++++++++
-- without schema privileges, non-superusers can do nothing.
GRANT USAGE on SCHEMA shardsvrdb to shardwebserver;
GRANT CONNECT ON database shardsvrdb  TO shardwebserver;

-- no access to email_blocked or email_blocked_sources?
GRANT INSERT ON ALL TABLES IN SCHEMA shardsvrdb TO shardwebserver;
GRANT UPDATE ON ALL TABLES IN SCHEMA shardsvrdb TO shardwebserver;
--GRANT SELECT ON ALL TABLES IN SCHEMA shardsvrdb TO shardwebserver;
GRANT DELETE ON ALL TABLES IN SCHEMA shardsvrdb TO shardwebserver;

-- this is access for the thing (function/process??) that
-- will actually determine the seq numbers for the autonumbered
-- serial.
GRANT USAGE, SELECT ON SEQUENCE shardsvrdb.big_shards_big_shard_pkid_seq  TO shardwebserver;

GRANT INSERT ON shardsvrdb.big_shards TO shardwebserver;
GRANT UPDATE ON shardsvrdb.big_shards TO shardwebserver;
GRANT SELECT ON shardsvrdb.big_shards TO shardwebserver;
GRANT DELETE ON shardsvrdb.big_shards TO shardwebserver;

--

GRANT USAGE, SELECT ON SEQUENCE shardsvrdb.shard_big_kill_pending_shard_big_kill_pending_pkid_seq  TO shardwebserver;

GRANT INSERT ON shardsvrdb.shard_big_kill_pending TO shardwebserver;
GRANT UPDATE ON shardsvrdb.shard_big_kill_pending TO shardwebserver;
GRANT SELECT ON shardsvrdb.shard_big_kill_pending TO shardwebserver;
GRANT DELETE ON shardsvrdb.shard_big_kill_pending TO shardwebserver;




-- show the tables
--\dt shardsvrdb.*

--show permissions for the msg table
--\dp shardsvrdb.*

