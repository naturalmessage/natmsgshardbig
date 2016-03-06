-- upgrade_0_0_5.sql
-- Note: I use underlines in 0_0_5 so that all instances of
--	the version identifier can be the same, and python
--	did not allow hyphens in the name of imported modules.

-- Error traps in PostgreSQL user functions (not regular SQL) are described in
-- section 40.6.6 of the 9.3 manual.  You can put any of the errors
-- from appendix A into a "WHEN ... EXCEPTION..." block.
--
-- The postgre 9.3 manual says:
--   "The fields sqlca.sqlstate and sqlca.sqlcode are two different schemes that
--   provide error codes.  Both are derived from the SQL standard, but SQLCODE has
--   been marked deprecated in the SQL-92 edition of the standard and has been
--   dropped in later editions. Therefore, new applications are strongly encouraged
--   to use SQLSTATE .

-- A list of SQLSTATE error codes starts on page 800 of the 9.3 manual.
-- Other error codes are in Appendix A.

-- Error codes, pg93 manual section 33.8.2. sqlca
-- sqlca.sqlcode will be 0 if there was no error on the previous command.
--   "If the last SQL statement was successful, then sqlca.sqlerrd[1] 
--   contains the OID of the processed row, if applicable, and 
--   sqlca.sqlerrd[2] contains the number of processed or returned 
--   rows, if applicable to the command."
--
--   "In case of an error or warning, sqlca.sqlerrm.sqlerrmc will 
--   contain a string that describes the error. The field 
--   sqlca.sqlerrm.sqlerrml contains the length of the error 
--   message that is stored in sqlca.sqlerrm.sqlerrmc

--  "In case of a warning, sqlca.sqlwarn[2] is set to W . 
--  (In all other cases, it is set to something different
--  from W .)"

drop function IF EXISTS shard.upgrade_0_0_5(db_name char);

CREATE FUNCTION shard.upgrade_0_0_5(db_name char) RETURNS int AS $$
DECLARE
rnd_int int;
rows_check int;
BEGIN

	BEGIN
		-- see if the column 'abc' exists
		-- by looking at the information_schema table
		-- table_catalog equals 'sharddb' or 'sharddbtest'
		-- (which should be a user argument),
		-- table_schema equlas 'shard'
		--    select 
		--      table_name,  
		--      column_name,  
		--      ordinal_position,   
		--      column_default,   
		--      is_nullable,   
		--      data_type,   
		--      character_maximum_length,  
		--      character_octet_length 
		--    FROM information_schema.columns
		--    WHERE table_name = 'shards'
		--      and table_catalog = 'sharddb'
		--      and table_schema  = 'shard';
		PERFORM table_name, column_name
		FROM information_schema.columns
		WHERE table_schema  = 'shard'
			and table_catalog = db_name
			and table_name = 'shards'
			and column_name = 'shard_server_pkid';

		GET DIAGNOSTICS rows_check = ROW_COUNT;
		IF rows_check = 0 THEN
			-- The table does not have this row, so add it, 
			-- and prepare to change the other keys field names in other 
			-- tables.
			-- WARNING: a note on page 118 of the 9.3 manual is confusing,
			-- but it might say that 'searial' no longer implies 'UNIQUE.'
			ALTER TABLE shard.shard_servers 
			ADD COLUMN shard_server_pkid serial UNIQUE NOT NULL;

			ALTER TABLE shard.shard_server_tests 
			ADD COLUMN shard_server_test_pkid serial UNIQUE NOT NULL;

			ALTER TABLE shard.shard_server_tests
			ADD COLUMN shard_server_pkid serial UNIQUE NOT NULL;

			RAISE NOTICE 'After adding columns.';

			UPDATE shard.shard_servers SET shard_server_pkid = shard_server_id;

			UPDATE shard.shard_server_tests
			SET shard_server_test_pkid = shard_server_test_id;

			UPDATE shard.shard_server_tests
			SET shard_server_pkid = shard_server_id;

			RAISE NOTICE 'After updating the new column values.';
			-- Remove a foreign key constraint from a table that
			-- refers to the shards table. Here is an earlier err msg:
			--   constraint shard_server_tests_shard_server_id_fkey 
			--   on table shard.shard_server_tests depends on table 
			--   shard.shard_servers column shard_server_id
			ALTER TABLE shard.shard_server_tests 
			DROP CONSTRAINT shard_server_tests_shard_server_id_fkey;

			-- Note: the 'DROP INDEX' command is NOT part of 'ALTER TABLE.'
			DROP INDEX IF EXISTS idx_shard_server_test_fk;

			RAISE NOTICE 'After droping constraint shard_server_tests_shard_server_id_fkey';

			ALTER TABLE shard.shard_servers DROP COLUMN shard_server_id;

			RAISE NOTICE 'After droping the old PK';

			-- Rebuild the foreign key constraint.
			ALTER TABLE shard.shard_server_tests ADD FOREIGN KEY (shard_server_pkid)
			REFERENCES shard.shard_servers(shard_server_pkid);

			---- The indiex might have beencdreate automatically 
			---- when the foreign key was created.
			--CREATE INDEX idx_shard_server_test_fk on shard.shard_server_tests(shard_server_pkid);


			-- drop unwanted tables
			-- ERROR:  cannot drop table shard.private_box_info because other objects depend on it
			--DETAIL:  constraint box_translator_private_box_id_fkey on table shard.box_translator depends on table shard.private_box_info

			ALTER TABLE shard.box_translator
			DROP CONSTRAINT shard.box_translator_private_box_id_fkey;


			DROP CONSTRAINT shard.email_blocked_email_block_source_fkey;
			-- on table shard.email_blocked depends on table shard.email_block_sources


			DROP TABLE shard.private_box_info;
			DROP TABLE shard.email_block_sources;
			-- drop and rebuild the blog tables
			DROP TABLE shard.nm_blog_entries;
			DROP TABLE shard.nm_blog_ids;
			DROP TABLE shard.nm_blog_formats;
			-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
				--++++++++++++++++++++++++++++++++++++++++++++
				-- the blog formats are 'json' or 'html'
				CREATE TABLE IF NOT EXISTS shard.nm_blog_formats(
					nm_blog_format_pkid     serial PRIMARY KEY,
					nm_blog_format         int not null UNIQUE,
					nm_blog_format_name    char(10)
				);
				-- define the two types:
				insert into shard.nm_blog_formats(nm_blog_format, nm_blog_format_name) VALUES(1, 'json');
				insert into shard.nm_blog_formats(nm_blog_format, nm_blog_format_name) VALUES(2, 'html');

				-- NOTE NOV 3 2014, i changed the name of the table from
				-- nm_blog_ids to nm_blog_names.
				-- NOTE NOV 3 2014, i changed nm_blog_id_pkid to nm_blog_pkid
				CREATE TABLE IF NOT EXISTS shard.nm_blog_names(
					nm_blog_pkid           serial PRIMARY KEY,
					nm_blog_name           char(100) not null UNIQUE,
					nm_blog_format         int
				);
				insert into shard.nm_blog_names(nm_blog_name, nm_blog_format) VALUES('Server Status', 1);
				ALTER TABLE shard.nm_blog_names ADD FOREIGN KEY (nm_blog_format)
				REFERENCES shard.nm_blog_formats(nm_blog_format);

				-- NOTE NOV 3 2014, i changed nm_blog_id to nm_blog_pkid
				CREATE TABLE IF NOT EXISTS shard.nm_blog_entries(
					nm_blog_entry_pkid      serial PRIMARY KEY,
					nm_blog_pkid         int,
					nm_blog_entry          text,
					nm_blog_date           timestamp not null default CURRENT_TIMESTAMP
				);
				ALTER TABLE shard.nm_blog_entries ADD FOREIGN KEY (nm_blog_pkid) REFERENCES shard.nm_blog_names(nm_blog_pkid);


				GRANT USAGE, SELECT ON SEQUENCE shard.nm_blog_entries_nm_blog_entry_pkid_seq  TO shardwebserver;

				GRANT INSERT ON shard.nm_blog_entries TO shardwebserver;
				GRANT UPDATE ON shard.nm_blog_entries TO shardwebserver;
				GRANT SELECT ON shard.nm_blog_entries TO shardwebserver;
				GRANT DELETE ON shard.nm_blog_entries TO shardwebserver;
				--

				-- NOV 3, 2014, i changed blog_id_pkid to blog_pkid in the seq name.
				GRANT USAGE, SELECT ON SEQUENCE shard.nm_blog_ids_nm_blog_pkid_seq  TO shardwebserver;

				GRANT INSERT ON shard.nm_blog_ids TO shardwebserver;
				GRANT UPDATE ON shard.nm_blog_ids TO shardwebserver;
				GRANT SELECT ON shard.nm_blog_ids TO shardwebserver;
				GRANT DELETE ON shard.nm_blog_ids TO shardwebserver;
				--
				GRANT USAGE, SELECT ON SEQUENCE shard.nm_blog_formats_nm_blog_format_pkid_seq  TO shardwebserver;

				GRANT INSERT ON shard.nm_blog_formats TO shardwebserver;
				GRANT UPDATE ON shard.nm_blog_formats TO shardwebserver;
				GRANT SELECT ON shard.nm_blog_formats TO shardwebserver;
				GRANT DELETE ON shard.nm_blog_formats TO shardwebserver;

--++++++++++++++++++++++++++++++++++++++++++++
			-- XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
			RAISE NOTICE 'DONE';

		END IF;

		-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
		-- remove the constraint for shard size -- for testing
		-- \d information_schema.referential_constraints
		--
		-- SELECT * FROM information_schema.check_constraints 
		-- WHERE constraint_name LIKE 'shard%';

		PERFORM * FROM information_schema.check_constraints 
		WHERE constraint_name = 'shards_shard_check';
		GET DIAGNOSTICS rows_check = ROW_COUNT;
		IF rows_check > 0 THEN
			-- the table has the constraint that I want to drop for testing
			ALTER TABLE shard.shard_servers DROP CONSTRAINT shards_shard_check;
		END IF;

		-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
		-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
		-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
		-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --
		-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --

		-- -- EXCEPTION
		-- -- 	WHEN division_by_zero THEN
		-- -- 		RAISE NOTICE 'caught division_by_zero';
		-- -- 		--The RAISE EXCEPTION version will return immediately
		-- -- 		--RAISE EXCEPTION 'caught division_by_zero';
		-- -- 		-- RETURN x;
		-- -- 		RETURN 333;
	END;

	RETURN 0;
END
$$
LANGUAGE 'plpgsql';

-- -- run it like this:
-- -- select shard.upgrade_0_0_5('sharddbtest');


