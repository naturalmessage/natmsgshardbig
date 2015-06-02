
CREATE SCHEMA shardsvr;
                                                                                  
CREATE USER shardwebserver;                                                                                               
ALTER ROLE shardwebserver WITH LOGIN;                                                                                     
ALTER ROLE shardwebserver with CONNECTION LIMIT 400;                                                                       
ALTER ROLE shardwebserver with password 'ENTER_THE_DATABASE_PASSWORD';   
--
-- Note: Without schema privileges, non-superusers can do nothing.
GRANT USAGE on SCHEMA shardsvr to shardwebserver;
GRANT CONNECT ON database shardsvrdb  TO shardwebserver;
-- no access to email_blocked or email_blocked_sources?
GRANT INSERT ON ALL TABLES IN SCHEMA shardsvr TO shardwebserver;
GRANT UPDATE ON ALL TABLES IN SCHEMA shardsvr TO shardwebserver;
--GRANT SELECT ON ALL TABLES IN SCHEMA shardsvr TO shardwebserver;
GRANT DELETE ON ALL TABLES IN SCHEMA shardsvr TO shardwebserver;

-- ------------------------------
