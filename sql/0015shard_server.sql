-- ++++++++++++++++++++++++++++++++++++++++++++++++
-- This is for the "little shard" servers.  
--
-- This stores the cargo ina PostgreSQL 'Bytea'
-- column, which is inefficient because you have
-- to convert to ascii hex before loading into the
-- database, but this would save space compared to
-- wasting a 4KB sector on disk. The current
-- system requires that uploadd shards be in base64
-- format, so it might make sense to change the 'shard'
-- storage to varchar.

-- Note that the size constraint is for the internal
-- hex representation of the data, which is higher
-- than the original shard length.
-- The 'retention minutes' field will facilitate chat
-- in the future, but is not currently used.
--
-- 
--drop table shardsvrdb.shards;
CREATE TABLE IF NOT EXISTS shardsvrdb.shards(
shard_pkid               BIGSERIAL PRIMARY KEY,
shard_id                 CHAR(35) NOT NULL,
shard                    BYTEA NOT NULL,
retention_minutes        INT NOT NULL DEFAULT 0,
-- allow null on expire date
expire_on_date           DATE DEFAULT current_date + 5,
delete_db_entry_on_date  DATE DEFAULT current_date + 20 NOT NULL,
burned                   BOOLEAN DEFAULT false NOT NULL,
expired                  BOOLEAN DEFAULT false NOT NULL,
encryption_format        INT DEFAULT 0 NOT NULL,
last_accessed_yyyymmdd   DATE NOT NULL DEFAULT current_date,
CHECK (length(shard)  < 600)
);
create unique index idx_shard_id on shardsvrdb.shards(shard_id);

--++++++++++++++++++++++++++++++++++++++++++++
--++++++++++++++++++++++++++++++++++++++++++++
--++++++++++++++++++++++++++++++++++++++++++++
--++++++++++++++++++++++++++++++++++++++++++++
-- without schema privileges, non-superusers can do nothing.
GRANT USAGE on SCHEMA shardsvrdb to shardwebserver;
GRANT CONNECT ON database sharddb  TO shardwebserver;

-- no access to email_blocked or email_blocked_sources?
GRANT INSERT ON ALL TABLES IN SCHEMA shardsvrdb TO shardwebserver;
GRANT UPDATE ON ALL TABLES IN SCHEMA shardsvrdb TO shardwebserver;
--GRANT SELECT ON ALL TABLES IN SCHEMA shardsvrdb TO shardwebserver;
GRANT DELETE ON ALL TABLES IN SCHEMA shardsvrdb TO shardwebserver;

-- this is access for the thing (function/process??) that
-- will actually determine the seq numbers for the autonumbered
-- serial.
GRANT INSERT ON shardsvrdb.shards TO shardwebserver;
GRANT UPDATE ON shardsvrdb.shards TO shardwebserver;
GRANT SELECT ON shardsvrdb.shards TO shardwebserver;
GRANT DELETE ON shardsvrdb.shards TO shardwebserver;


-- this is access for the thing (function/process??) that
-- will actually determine the seq numbers for the autonumbered
-- serial.
GRANT USAGE, SELECT ON SEQUENCE shardsvrdb.shards_shard_pkid_seq  TO shardwebserver;


-- show the tables
--\dt shardsvrdb.*

--show permissions for the msg table
--\dp shardsvrdb.*

