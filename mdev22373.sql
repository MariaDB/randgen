DROP TABLE IF EXISTS `t1`;
CREATE TABLE `t1` (
  `c01` int(8) NOT NULL AUTO_INCREMENT,
  `c02` varchar(8) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '',
  `c03` int(8) NOT NULL DEFAULT 0,
  `c04` varchar(24) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '',
  `c05` int(8) NOT NULL DEFAULT 0,
  `c06` bit(1) NOT NULL DEFAULT b'0',
  `c07` varchar(6) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '2020',
  `c08` smallint(4) NOT NULL DEFAULT 9999,
  `c10` varchar(32) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '',
  `c18` bit(1) NOT NULL DEFAULT b'0',
  `c21` datetime NOT NULL DEFAULT '1000-01-01 00:00:00',
  `c30` varchar(255) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '',
  `c22` smallint(4) NOT NULL DEFAULT 30,
  `c23` smallint(4) NOT NULL DEFAULT 0,
  `c24` smallint(4) NOT NULL DEFAULT 0,
  `c25` varchar(255) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '',
  `c26` smallint(4) NOT NULL DEFAULT 0,
  `c27` int(10) NOT NULL DEFAULT 0,
  `c28` bit(1) NOT NULL DEFAULT b'0',
  `c29` bigint(12) NOT NULL DEFAULT 1000000,
  PRIMARY KEY (`c01`),
  KEY `c03` (`c03`),
  KEY `c04` (`c04`),
  KEY `c05` (`c05`),
  KEY `x` (`c06`,`c07`,`c08`,`c10`),
  KEY `xx` (`c18`,`c21`,`c30`,`c22`),
  KEY `xxx` (`c23`,`c24`,`c25`,`c26`,`c27`),
  KEY `xxxx` (`c29`,`c28`,`c27`),
  KEY `idx1289000_3` (`c18`,`c28`,`c21`,`c05`,`c29`,`c22`,`c06`,`c24`,`c01`,`c23`,`c25`,`c04`,`c27`,`c26`),
  KEY `idx1289006_2` (`c25`,`c27`,`c05`,`c30`,`c01`,`c08`,`c10`),
  KEY `idx1289012_5` (`c26`,`c01`,`c03`,`c22`,`c08`,`c23`,`c24`,`c07`,`c30`,`c05`,`c04`,`c18`,`c25`,`c10`,`c28`,`c27`),
  KEY `idx1289016_5` (`c08`,`c07`,`c03`,`c25`,`c01`,`c26`,`c27`,`c18`,`c22`,`c06`,`c28`,`c21`,`c10`,`c29`,`c02`,`c24`,`c05`,`c30`),
  KEY `idx1289027_4` (`c05`,`c04`,`c06`,`c27`,`c24`,`c28`,`c30`,`c01`,`c10`,`c02`,`c07`,`c03`,`c29`,`c25`,`c21`,`c23`,`c26`,`c18`),
  KEY `idx1289038_3` (`c24`,`c26`,`c06`,`c07`,`c23`),
  KEY `idx1289048_2` (`c05`,`c21`,`c10`,`c18`,`c06`,`c30`,`c23`,`c02`,`c03`,`c27`,`c22`,`c04`,`c26`,`c24`,`c28`,`c07`,`c01`,`c29`),
  KEY `idx1289054_4` (`c23`,`c01`,`c02`,`c08`,`c27`,`c10`),
  KEY `idx1289060_2` (`c26`,`c28`,`c25`,`c24`,`c01`,`c18`,`c10`,`c23`,`c08`,`c05`),
  KEY `idx1289042_5` (`c03`,`c30`,`c08`),
  KEY `idx1289046_4` (`c07`,`c18`),
  KEY `idx1289070_5` (`c05`,`c28`,`c23`,`c21`,`c02`,`c26`,`c03`,`c27`,`c01`,`c04`,`c07`,`c06`,`c10`,`c29`,`c25`,`c30`,`c22`,`c24`),
  KEY `idx1289096_5` (`c25`,`c30`,`c24`,`c10`,`c01`,`c26`,`c08`,`c22`,`c27`,`c02`,`c05`,`c23`)
) ENGINE=InnoDB AUTO_INCREMENT=5002 DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `t2`;
CREATE TABLE `t2` (
  `cl_from` int(8) unsigned NOT NULL DEFAULT 0,
  `cl_to` varbinary(255) NOT NULL DEFAULT '',
  `cl_sortkey` varbinary(230) NOT NULL DEFAULT '',
  `cl_timestamp` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `cl_sortkey_prefix` varbinary(255) NOT NULL DEFAULT '',
  `cl_collation` varbinary(32) NOT NULL DEFAULT '',
  `cl_type` enum('page','subcat','file') NOT NULL DEFAULT 'page',
  PRIMARY KEY (`cl_from`,`cl_to`),
  KEY `cl_timestamp` (`cl_to`,`cl_timestamp`),
  KEY `cl_sortkey` (`cl_to`,`cl_type`,`cl_sortkey`,`cl_from`),
  KEY `cl_collation_ext` (`cl_collation`,`cl_to`,`cl_type`,`cl_from`),
  KEY `idx1289006_3` (`cl_type`),
  KEY `idx1289020_2` (`cl_sortkey_prefix`,`cl_sortkey`,`cl_from`,`cl_timestamp`),
  KEY `idx1289012_3` (`cl_timestamp`,`cl_from`,`cl_type`),
  KEY `idx1289034_5` (`cl_to`,`cl_timestamp`,`cl_collation`),
  KEY `idx1289056_1` (`cl_sortkey_prefix`),
  KEY `idx1289036_3` (`cl_from`,`cl_collation`,`cl_sortkey_prefix`,`cl_to`),
  KEY `idx1289042_4` (`cl_from`,`cl_sortkey_prefix`,`cl_timestamp`,`cl_to`,`cl_sortkey`,`cl_type`),
  KEY `idx1289044_5` (`cl_sortkey`,`cl_timestamp`,`cl_to`,`cl_collation`,`cl_sortkey_prefix`,`cl_type`),
  KEY `idx1289070_1` (`cl_from`,`cl_type`,`cl_to`,`cl_collation`),
  KEY `idx1289074_2` (`cl_from`,`cl_collation`,`cl_sortkey_prefix`,`cl_sortkey`),
  KEY `idx1289072_4` (`cl_sortkey_prefix`,`cl_from`,`cl_to`,`cl_timestamp`,`cl_sortkey`,`cl_type`,`cl_collation`),
  KEY `idx1289084_1` (`cl_from`,`cl_sortkey_prefix`,`cl_timestamp`,`cl_collation`),
  KEY `idx1289062_5` (`cl_to`,`cl_timestamp`,`cl_sortkey_prefix`,`cl_sortkey`,`cl_type`,`cl_collation`,`cl_from`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `t3`;
CREATE TABLE `t3` (
  `ftr_from` int(10) unsigned NOT NULL DEFAULT 0,
  `ftr_namespace` int(11) NOT NULL DEFAULT 0,
  `ftr_title` varbinary(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`ftr_from`),
  KEY `from_namespace_title` (`ftr_from`,`ftr_namespace`,`ftr_title`),
  KEY `namespace_title_from` (`ftr_namespace`,`ftr_title`,`ftr_from`),
  KEY `idx1289000_1` (`ftr_title`,`ftr_namespace`,`ftr_from`),
  KEY `idx1289000_2` (`ftr_title`),
  KEY `idx1289001_2` (`ftr_from`,`ftr_title`,`ftr_namespace`),
  KEY `idx1289012_1` (`ftr_namespace`,`ftr_title`),
  KEY `idx1289010_4` (`ftr_title`,`ftr_from`),
  KEY `idx1289027_1` (`ftr_from`,`ftr_title`),
  KEY `idx1289090_3` (`ftr_title`,`ftr_namespace`),
  KEY `idx1289080_4` (`ftr_namespace`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `t4`;
CREATE TABLE `t4` (
  `score_id` int(13) NOT NULL,
  `publisher_id` int(4) NOT NULL,
  `user_id` int(13) NOT NULL,
  `user_name` varchar(20) NOT NULL,
  `score_value` int(13) NOT NULL,
  `archive_type` char(1) NOT NULL,
  `tag` varchar(32) NOT NULL,
  PRIMARY KEY (`score_id`,`publisher_id`,`archive_type`,`user_id`,`tag`),
  KEY `score_id` (`score_id`,`publisher_id`,`archive_type`,`tag`),
  KEY `archive_type` (`archive_type`,`publisher_id`),
  KEY `archive_type_2` (`archive_type`),
  KEY `publisher_id` (`publisher_id`,`score_id`,`tag`),
  KEY `score_value` (`score_value`),
  KEY `score_sort` (`publisher_id`,`score_id`,`tag`,`score_value`,`archive_type`),
  KEY `score_sort_sans_tag` (`publisher_id`,`score_id`,`archive_type`,`score_value`),
  KEY `score_id_sans_tag` (`publisher_id`,`score_id`,`archive_type`),
  KEY `idx1289027_2` (`user_name`,`score_value`,`tag`,`archive_type`,`user_id`,`score_id`),
  KEY `idx1289054_2` (`score_value`,`score_id`,`user_id`,`tag`,`user_name`),
  KEY `idx1289058_3` (`tag`,`archive_type`,`score_id`,`score_value`),
  KEY `idx1289078_2` (`user_name`,`publisher_id`),
  KEY `idx1289076_5` (`score_id`,`user_id`,`user_name`,`tag`,`publisher_id`),
  KEY `idx1289092_1` (`score_id`,`score_value`,`user_id`,`user_name`,`tag`),
  KEY `idx1289096_4` (`publisher_id`,`score_id`,`tag`,`user_id`),
  KEY `idx1289106_1` (`publisher_id`,`score_id`,`archive_type`,`tag`,`score_value`,`user_name`,`user_id`),
  KEY `idx1289094_3` (`archive_type`,`user_name`,`score_id`),
  KEY `idx1289100_5` (`archive_type`,`tag`,`score_value`,`score_id`,`user_id`),
  KEY `idx1289120_1` (`publisher_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `t5`;
CREATE TABLE `t5` (
  `iwl_from` int(10) unsigned NOT NULL DEFAULT 0,
  `iwl_prefix` varbinary(20) NOT NULL DEFAULT '',
  `iwl_title` varbinary(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`iwl_from`,`iwl_prefix`,`iwl_title`),
  KEY `iwl_prefix_title_from` (`iwl_prefix`,`iwl_title`,`iwl_from`),
  KEY `iwl_prefix_from_title` (`iwl_prefix`,`iwl_from`,`iwl_title`),
  KEY `idx1289020_1` (`iwl_prefix`),
  KEY `idx1289018_2` (`iwl_title`,`iwl_from`,`iwl_prefix`),
  KEY `idx1289024_5` (`iwl_from`),
  KEY `idx1289032_2` (`iwl_prefix`,`iwl_title`),
  KEY `idx1289036_1` (`iwl_title`,`iwl_prefix`),
  KEY `idx1289052_3` (`iwl_title`,`iwl_from`),
  KEY `idx1289064_1` (`iwl_title`),
  KEY `idx1289078_1` (`iwl_prefix`,`iwl_from`),
  KEY `idx1289082_2` (`iwl_from`,`iwl_prefix`),
  KEY `idx1289124_4` (`iwl_from`,`iwl_title`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `t6`;
CREATE TABLE `t6` (
  `rc_id` int(8) NOT NULL AUTO_INCREMENT,
  `rc_timestamp` varbinary(14) NOT NULL DEFAULT '',
  `rc_actor` bigint(20) unsigned NOT NULL,
  `rc_namespace` int(11) NOT NULL DEFAULT 0,
  `rc_title` varbinary(255) NOT NULL DEFAULT '',
  `rc_comment_id` bigint(20) unsigned NOT NULL,
  `rc_minor` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `rc_bot` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `rc_new` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `rc_cur_id` int(10) unsigned NOT NULL DEFAULT 0,
  `rc_this_oldid` int(10) unsigned NOT NULL DEFAULT 0,
  `rc_last_oldid` int(10) unsigned NOT NULL DEFAULT 0,
  `rc_type` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `rc_source` varbinary(16) NOT NULL DEFAULT '',
  `rc_patrolled` tinyint(3) unsigned NOT NULL DEFAULT 0,
  `rc_ip` varbinary(40) NOT NULL DEFAULT '',
  `rc_old_len` int(10) DEFAULT NULL,
  `rc_new_len` int(10) DEFAULT NULL,
  `rc_deleted` tinyint(1) unsigned NOT NULL DEFAULT 0,
  `rc_logid` int(10) unsigned NOT NULL DEFAULT 0,
  `rc_log_type` varbinary(255) DEFAULT NULL,
  `rc_log_action` varbinary(255) DEFAULT NULL,
  `rc_params` blob NOT NULL,
  PRIMARY KEY (`rc_id`),
  KEY `rc_timestamp` (`rc_timestamp`),
  KEY `rc_cur_id` (`rc_cur_id`),
  KEY `new_name_timestamp` (`rc_new`,`rc_namespace`,`rc_timestamp`),
  KEY `rc_ip` (`rc_ip`),
  KEY `rc_name_type_patrolled_timestamp` (`rc_namespace`,`rc_type`,`rc_patrolled`,`rc_timestamp`),
  KEY `rc_comment_deleted` (`rc_comment_id`,`rc_deleted`),
  KEY `rc_ns_actor` (`rc_namespace`,`rc_actor`),
  KEY `rc_actor` (`rc_actor`,`rc_timestamp`),
  KEY `rc_namespace_title_timestamp` (`rc_namespace`,`rc_title`,`rc_timestamp`),
  KEY `rc_actor_deleted` (`rc_actor`,`rc_deleted`),
  KEY `rc_this_oldid` (`rc_this_oldid`),
  KEY `idx1289002_5` (`rc_namespace`,`rc_source`,`rc_log_action`,`rc_old_len`,`rc_log_type`,`rc_patrolled`,`rc_comment_id`,`rc_deleted`,`rc_logid`,`rc_this_oldid`),
  KEY `idx1289004_4` (`rc_old_len`,`rc_this_oldid`,`rc_title`,`rc_timestamp`,`rc_log_type`),
  KEY `idx1289020_4` (`rc_last_oldid`,`rc_cur_id`),
  KEY `idx1289036_2` (`rc_new_len`,`rc_title`,`rc_source`,`rc_log_action`,`rc_last_oldid`,`rc_deleted`,`rc_old_len`,`rc_patrolled`,`rc_namespace`,`rc_actor`),
  KEY `idx1289044_1` (`rc_minor`,`rc_timestamp`,`rc_new_len`,`rc_cur_id`,`rc_ip`,`rc_new`,`rc_log_type`,`rc_namespace`,`rc_title`,`rc_comment_id`,`rc_type`,`rc_bot`,`rc_actor`),
  KEY `idx1289060_3` (`rc_title`,`rc_patrolled`,`rc_minor`,`rc_id`,`rc_old_len`,`rc_last_oldid`,`rc_actor`),
  KEY `idx1289046_3` (`rc_new_len`,`rc_cur_id`,`rc_log_type`,`rc_comment_id`),
  KEY `idx1289086_1` (`rc_patrolled`,`rc_source`,`rc_new_len`,`rc_log_action`,`rc_log_type`,`rc_new`,`rc_comment_id`),
  KEY `idx1289100_1` (`rc_log_action`,`rc_type`,`rc_old_len`,`rc_id`,`rc_bot`,`rc_namespace`)
) ENGINE=InnoDB AUTO_INCREMENT=5260 DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `t7`;
CREATE TABLE `t7` (
  `rev_id` int(8) unsigned NOT NULL AUTO_INCREMENT,
  `rev_page` int(8) unsigned NOT NULL DEFAULT 0,
  `rev_text_id` int(8) unsigned NOT NULL DEFAULT 0,
  `rev_comment` varbinary(255) NOT NULL DEFAULT '',
  `rev_user` int(5) unsigned NOT NULL DEFAULT 0,
  `rev_user_text` varbinary(255) NOT NULL DEFAULT '',
  `rev_timestamp` varbinary(14) NOT NULL DEFAULT '',
  `rev_minor_edit` tinyint(1) unsigned NOT NULL DEFAULT 0,
  `rev_deleted` tinyint(1) unsigned NOT NULL DEFAULT 0,
  `rev_len` int(8) unsigned DEFAULT NULL,
  `rev_parent_id` int(8) unsigned DEFAULT NULL,
  `rev_sha1` varbinary(32) NOT NULL DEFAULT '',
  `rev_content_model` varbinary(32) DEFAULT NULL,
  `rev_content_format` varbinary(64) DEFAULT NULL,
  PRIMARY KEY (`rev_id`),
  KEY `rev_timestamp` (`rev_timestamp`),
  KEY `page_timestamp` (`rev_page`,`rev_timestamp`),
  KEY `user_timestamp` (`rev_user`,`rev_timestamp`),
  KEY `usertext_timestamp` (`rev_user_text`,`rev_timestamp`),
  KEY `page_user_timestamp` (`rev_page`,`rev_user`,`rev_timestamp`),
  KEY `rev_page_id` (`rev_page`,`rev_id`),
  KEY `idx1289012_2` (`rev_user`,`rev_page`),
  KEY `idx1289010_2` (`rev_deleted`,`rev_text_id`,`rev_parent_id`,`rev_user_text`,`rev_sha1`,`rev_len`,`rev_content_format`,`rev_comment`,`rev_minor_edit`,`rev_user`,`rev_content_model`,`rev_page`,`rev_id`),
  KEY `idx1289016_3` (`rev_text_id`,`rev_comment`,`rev_len`,`rev_user`,`rev_content_format`,`rev_content_model`,`rev_user_text`,`rev_page`,`rev_deleted`,`rev_minor_edit`),
  KEY `idx1289034_3` (`rev_text_id`),
  KEY `idx1289040_3` (`rev_user`,`rev_comment`,`rev_deleted`,`rev_minor_edit`,`rev_len`,`rev_page`,`rev_timestamp`),
  KEY `idx1289050_4` (`rev_deleted`,`rev_content_format`),
  KEY `idx1289042_3` (`rev_comment`,`rev_page`,`rev_id`,`rev_content_format`,`rev_content_model`,`rev_user`,`rev_sha1`,`rev_minor_edit`,`rev_user_text`,`rev_timestamp`,`rev_text_id`),
  KEY `idx1289048_4` (`rev_user_text`,`rev_minor_edit`,`rev_page`,`rev_content_format`,`rev_text_id`,`rev_len`,`rev_timestamp`,`rev_id`,`rev_deleted`,`rev_sha1`,`rev_comment`,`rev_parent_id`,`rev_content_model`),
  KEY `idx1289064_2` (`rev_user_text`,`rev_parent_id`,`rev_id`,`rev_comment`,`rev_content_model`,`rev_user`,`rev_text_id`,`rev_deleted`,`rev_minor_edit`,`rev_timestamp`,`rev_page`,`rev_sha1`),
  KEY `idx1289066_3` (`rev_deleted`,`rev_user_text`,`rev_content_format`,`rev_len`,`rev_minor_edit`,`rev_user`,`rev_id`),
  KEY `idx1289072_5` (`rev_sha1`,`rev_text_id`,`rev_user_text`,`rev_id`,`rev_content_format`,`rev_comment`,`rev_timestamp`,`rev_parent_id`,`rev_page`,`rev_minor_edit`,`rev_len`,`rev_content_model`,`rev_user`,`rev_deleted`),
  KEY `idx1289084_4` (`rev_minor_edit`,`rev_text_id`,`rev_comment`,`rev_user`,`rev_content_format`,`rev_page`,`rev_user_text`,`rev_content_model`),
  KEY `idx1289092_2` (`rev_comment`,`rev_minor_edit`,`rev_len`,`rev_content_format`,`rev_content_model`,`rev_page`,`rev_text_id`,`rev_parent_id`),
  KEY `idx1289100_4` (`rev_minor_edit`,`rev_len`,`rev_user_text`,`rev_parent_id`,`rev_page`,`rev_sha1`),
  KEY `idx1289094_4` (`rev_len`,`rev_content_format`,`rev_user`,`rev_id`,`rev_comment`,`rev_timestamp`,`rev_user_text`,`rev_deleted`,`rev_parent_id`,`rev_content_model`,`rev_page`,`rev_minor_edit`,`rev_sha1`)
) ENGINE=InnoDB AUTO_INCREMENT=5509 DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `t8`;
CREATE TABLE `t8` (
  `revcomment_rev` int(10) unsigned NOT NULL,
  `revcomment_comment_id` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`revcomment_rev`,`revcomment_comment_id`),
  KEY `revcomment_rev` (`revcomment_rev`),
  KEY `revcomment_comment_id` (`revcomment_comment_id`),
  KEY `idx1289004_1` (`revcomment_comment_id`,`revcomment_rev`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

DROP TABLE IF EXISTS `t9`;
CREATE TABLE `t9` (
  `tl_from` int(8) unsigned NOT NULL DEFAULT 0,
  `tl_namespace` int(11) NOT NULL DEFAULT 0,
  `tl_title` varbinary(255) NOT NULL DEFAULT '',
  `tl_from_namespace` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`tl_from`,`tl_namespace`,`tl_title`),
  KEY `tl_namespace` (`tl_namespace`,`tl_title`,`tl_from`),
  KEY `tl_backlinks_namespace` (`tl_from_namespace`,`tl_namespace`,`tl_title`,`tl_from`),
  KEY `idx1289001_5` (`tl_namespace`,`tl_title`),
  KEY `idx1289024_2` (`tl_namespace`,`tl_from_namespace`,`tl_title`),
  KEY `idx1289024_4` (`tl_namespace`),
  KEY `idx1289034_4` (`tl_namespace`,`tl_from_namespace`),
  KEY `idx1289046_2` (`tl_title`,`tl_namespace`,`tl_from`,`tl_from_namespace`),
  KEY `idx1289044_2` (`tl_from`),
  KEY `idx1289056_2` (`tl_from_namespace`,`tl_namespace`,`tl_from`,`tl_title`),
  KEY `idx1289096_2` (`tl_from`,`tl_namespace`),
  KEY `idx1289104_4` (`tl_from_namespace`,`tl_namespace`),
  KEY `idx1289108_5` (`tl_from`,`tl_from_namespace`,`tl_title`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE OR REPLACE TABLE t1_1 LIKE t1;
CREATE OR REPLACE TABLE t2_1 LIKE t2;
CREATE OR REPLACE TABLE t3_1 LIKE t3;
CREATE OR REPLACE TABLE t4_1 LIKE t4;
CREATE OR REPLACE TABLE t5_1 LIKE t5;
CREATE OR REPLACE TABLE t6_1 LIKE t6;
CREATE OR REPLACE TABLE t7_1 LIKE t7;
CREATE OR REPLACE TABLE t8_1 LIKE t8;
CREATE OR REPLACE TABLE t9_1 LIKE t9;

CREATE OR REPLACE TABLE t1_2 LIKE t1;
CREATE OR REPLACE TABLE t2_2 LIKE t2;
CREATE OR REPLACE TABLE t3_2 LIKE t3;
CREATE OR REPLACE TABLE t4_2 LIKE t4;
CREATE OR REPLACE TABLE t5_2 LIKE t5;
CREATE OR REPLACE TABLE t6_2 LIKE t6;
CREATE OR REPLACE TABLE t7_2 LIKE t7;
CREATE OR REPLACE TABLE t8_2 LIKE t8;
CREATE OR REPLACE TABLE t9_2 LIKE t9;
