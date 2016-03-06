see upgrade_0_05 for code to automate the upgrade process.
this contains some notes for two upgrades from different versions to version 11
o

-------------------------------------
-- for old tabl

-- change the primary key to bigint
---- NO ALTER TABLE shard.smd_read_transactions ALTER COLUMN smd_read_pkid TYPE BIGSERIAL PRIMARY KEY;
ALTER TABLE shard.smd_read_transactions ALTER COLUMN smd_read_pkid TYPE int8;
ALTER TABLE shard.smd_read_transaction_data ALTER COLUMN smd_read_data_pkid TYPE int8;
ALTER TABLE shard.smd_read_transaction_data ALTER COLUMN smd_read_pkid TYPE int8;


-- -- undo these commands:
-- -- CREATE UNIQUE INDEX idx_box_translator02 ON shard.box_translator(private_box_id);
-- -- ALTER TABLE shard.box_translator ADD FOREIGN KEY (public_box_id) REFERENCES shard.public_box_info(public_box_id);
-- -- ALTER TABLE shard.box_translator ADD FOREIGN KEY (private_box_id) REFERENCES shard.private_box_info(private_box_id);

ALTER TABLE shard.box_translator DROP CONSTRAINT box_translator_private_box_id_fkey;
ALTER TABLE shard.box_translator DROP CONSTRAINT box_translator_private_box_id_fkey1;
ALTER TABLE shard.box_translator DROP CONSTRAINT box_translator_public_box_id_fkey;
ALTER TABLE shard.box_translator DROP CONSTRAINT box_translator_public_box_id_fkey1;


ALTER TABLE shard.private_box_info ALTER COLUMN private_box_id TYPE CHAR(141);
DROP TABLE shard.private_box_info;

ALTER TABLE shard.public_box_info ALTER COLUMN public_box_id TYPE CHAR(141);
ALTER TABLE shard.box_translator ALTER COLUMN public_box_id TYPE CHAR(141);
ALTER TABLE shard.box_translator ALTER COLUMN private_box_id TYPE CHAR(141)

-------------------------------------
-- a few updates from v7 to v9

CREATE TABLE IF NOT EXISTS shard.country_names(
  country_pkid BIGSERIAL primary key,
  country_code CHAR(2) UNIQUE not null,
  country_name VARCHAR(100)
);

insert into shard.shard_server_geo_zones(shard_server_geo_zone_name) values('North America');
insert into shard.shard_server_geo_zones(shard_server_geo_zone_name) values('South America');
insert into shard.shard_server_geo_zones(shard_server_geo_zone_name) values('East Asia');
insert into shard.shard_server_geo_zones(shard_server_geo_zone_name) values('Africa');
insert into shard.shard_server_geo_zones(shard_server_geo_zone_name) values('Europe');

ALTER TABLE shard.shard_servers ADD COLUMN shard_server_geo_zone_pkid   INT DEFAULT 0 NOT NULL;

----------------- upgrade from v9

ALTER TABLE shard.shard_metadata ALTER COLUMN dest_public_box_id TYPE CHAR(141);
ALTER TABLE shard.shard_servers ALTER COLUMN shard_server_ipv6 TYPE CHAR(30);

ALTER TABLE shard.shard_servers ADD COLUMN shard_server_type CHAR(10) DEFAULT 'shard' NOT NULL;

ALTER TABLE shard.shard_servers ADD COLUMN shard_server_sig_req  INT DEFAULT 0 NOT NULL;

ALTER TABLE shard.shard_servers ADD COLUMN shard_server_pow_req   INT DEFAULT 0 NOT NULL;


ALTER TABLE shard.shard_servers ADD COLUMN shard_server_online_pub_key_b64 VARCHAR(800) NOT NULL DEFAULT 'NA';
ALTER TABLE shard.shard_servers ADD COLUMN shard_server_offline_pub_key_b64 VARCHAR(800) NOT NULL DEFAULT 'NA';
CREATE INDEX idx_shard_svr_online_key  ON shard.shard_servers(shard_server_online_pub_key_b64);
CREATE INDEX idx_shard_svr_offline_key  ON shard.shard_servers(shard_server_offline_pub_key_b64);

ALTER TABLE shard.shard_servers DROP COLUMN shard_server_pub_key;

ALTER TABLE shard.shard_servers ADD COLUMN shard_server_port_nbr INT DEFAULT 443 NOT NULL;
-- privileges needed for idx?

-----------------
ALTER TABLE shard.sysmon_rec_counts DROP COLUMN  private_box_info;

-----------
-- fix the type of the 'home' shard server -- dangerous assumption
update shard.shard_servers set shard_server_type = 'help' where shard_server_id = 27;
nd shard_desc = 'Main HELP Server';
