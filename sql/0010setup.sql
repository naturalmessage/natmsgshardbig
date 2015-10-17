
-- the user id is shardwebserver and the databae is:
--    sharddb for the OLD directory server,
--    dirsvrdb for the NEW directory server,
--    shardsvrdb for the shard server and server farm
--
CREATE SCHEMA shardsvrdb;
                                                                                  
CREATE USER shardwebserver;                                                                                               
ALTER ROLE shardwebserver WITH LOGIN;                                                                                     
ALTER ROLE shardwebserver with CONNECTION LIMIT 40;                                                                       
ALTER ROLE shardwebserver with password 'ENTER_YOUR_database_PASSWORD';   
--
-- Note: Without schema privileges, non-superusers can do nothing.
GRANT USAGE on SCHEMA shardsvrdb to shardwebserver;
GRANT CONNECT ON database shardsvrdb  TO shardwebserver;
-- no access to email_blocked or email_blocked_sources?
GRANT INSERT ON ALL TABLES IN SCHEMA shardsvrdb TO shardwebserver;
GRANT UPDATE ON ALL TABLES IN SCHEMA shardsvrdb TO shardwebserver;
--GRANT SELECT ON ALL TABLES IN SCHEMA shardsvrdb TO shardwebserver;
GRANT DELETE ON ALL TABLES IN SCHEMA shardsvrdb TO shardwebserver;

-- ------------------------------
