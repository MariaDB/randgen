CREATE DATABASE IF NOT EXISTS oqgraph_db;
USE oqgraph_db;
CREATE TABLE oq_backing1 (origid INT UNSIGNED NOT NULL, destid INT UNSIGNED NOT NULL, PRIMARY KEY (origid, destid), KEY (destid));
CREATE TABLE oq_backing2 (origid INT UNSIGNED NOT NULL, destid INT UNSIGNED NOT NULL, PRIMARY KEY (origid, destid), KEY (destid));

CREATE TABLE oqgraph1 ( latch VARCHAR(32) NULL, origid BIGINT UNSIGNED NULL, destid BIGINT UNSIGNED NULL, weight DOUBLE NULL, seq BIGINT UNSIGNED NULL, linkid BIGINT UNSIGNED NULL, KEY (latch, origid, destid) USING HASH, KEY (latch, destid, origid) USING HASH ) ENGINE=OQGRAPH data_table='oq_backing1' origid='origid' destid='destid';
CREATE TABLE oqgraph2 ( latch VARCHAR(32) NULL, origid BIGINT UNSIGNED NULL, destid BIGINT UNSIGNED NULL, weight DOUBLE NULL, seq BIGINT UNSIGNED NULL, linkid BIGINT UNSIGNED NULL, KEY (latch, origid, destid) USING HASH, KEY (latch, destid, origid) USING HASH ) ENGINE=OQGRAPH data_table='oq_backing2' origid='origid' destid='destid';
