-- MariaDB dump 10.19  Distrib 10.4.19-MariaDB, for Linux (x86_64)
--
-- Host: localhost    Database: db1
-- ------------------------------------------------------
-- Server version	10.4.19-MariaDB

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `categorylinks`
--

CREATE DATABASE db1;
USE db1;

--
-- Table structure for table `tblname`
--

DROP TABLE IF EXISTS `tblname`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tblname` (
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
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tblname_2`
--

DROP TABLE IF EXISTS `tblname_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tblname_2` (
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
  KEY `idx1289000_4` (`c26`,`c07`,`c04`,`c25`,`c05`,`c30`,`c02`,`c01`,`c18`,`c29`,`c08`,`c28`,`c10`,`c27`,`c24`),
  KEY `idx1289002_4` (`c01`,`c28`,`c06`,`c25`,`c29`,`c23`,`c18`,`c24`,`c05`),
  KEY `idx1289004_3` (`c27`,`c28`),
  KEY `idx1289006_5` (`c18`),
  KEY `idx1289010_1` (`c07`,`c28`),
  KEY `idx1289020_3` (`c03`,`c07`,`c22`,`c30`,`c23`,`c02`,`c08`,`c06`,`c29`,`c04`,`c28`,`c10`,`c26`,`c24`,`c27`,`c01`,`c25`,`c21`,`c18`,`c05`),
  KEY `idx1289024_1` (`c04`,`c07`,`c10`,`c21`),
  KEY `idx1289032_4` (`c25`,`c07`,`c10`,`c03`),
  KEY `idx1289038_2` (`c18`,`c02`,`c01`,`c27`,`c05`,`c08`,`c21`,`c10`,`c26`,`c28`,`c29`,`c24`),
  KEY `idx1289038_4` (`c18`,`c30`,`c02`,`c26`,`c07`,`c22`,`c05`),
  KEY `idx1289040_1` (`c04`,`c22`,`c10`),
  KEY `idx1289036_4` (`c05`,`c24`,`c30`),
  KEY `idx1289058_4` (`c02`,`c18`,`c06`,`c07`,`c29`,`c23`,`c05`,`c21`),
  KEY `idx1289090_2` (`c25`,`c18`,`c01`,`c21`,`c08`,`c05`,`c27`,`c07`)
) ENGINE=InnoDB AUTO_INCREMENT=58599 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

DROP TABLE IF EXISTS `categorylinks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `categorylinks` (
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
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `categorylinks_2`
--

DROP TABLE IF EXISTS `categorylinks_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `categorylinks_2` (
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
  KEY `idx1289018_4` (`cl_to`,`cl_timestamp`,`cl_sortkey_prefix`,`cl_sortkey`,`cl_from`),
  KEY `idx1289018_5` (`cl_sortkey_prefix`,`cl_type`,`cl_sortkey`),
  KEY `idx1289016_4` (`cl_timestamp`,`cl_collation`,`cl_type`),
  KEY `idx1289032_3` (`cl_collation`,`cl_sortkey_prefix`),
  KEY `idx1289040_2` (`cl_from`,`cl_to`,`cl_sortkey_prefix`),
  KEY `idx1289040_4` (`cl_collation`,`cl_to`,`cl_timestamp`,`cl_sortkey`,`cl_from`,`cl_type`,`cl_sortkey_prefix`),
  KEY `idx1289070_2` (`cl_to`,`cl_sortkey`),
  KEY `idx1289074_3` (`cl_timestamp`,`cl_type`,`cl_from`,`cl_sortkey`,`cl_collation`,`cl_sortkey_prefix`),
  KEY `idx1289080_3` (`cl_collation`,`cl_sortkey`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `flaggedrevs_tracking`
--

DROP TABLE IF EXISTS `flaggedrevs_tracking`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `flaggedrevs_tracking` (
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
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `flaggedrevs_tracking_2`
--

DROP TABLE IF EXISTS `flaggedrevs_tracking_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `flaggedrevs_tracking_2` (
  `ftr_from` int(10) unsigned NOT NULL DEFAULT 0,
  `ftr_namespace` int(11) NOT NULL DEFAULT 0,
  `ftr_title` varbinary(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`ftr_from`),
  KEY `from_namespace_title` (`ftr_from`,`ftr_namespace`,`ftr_title`),
  KEY `namespace_title_from` (`ftr_namespace`,`ftr_title`,`ftr_from`),
  KEY `idx1289001_3` (`ftr_from`,`ftr_namespace`),
  KEY `idx1289002_1` (`ftr_title`,`ftr_namespace`,`ftr_from`),
  KEY `idx1289004_5` (`ftr_title`),
  KEY `idx1289008_5` (`ftr_namespace`),
  KEY `idx1289020_5` (`ftr_title`,`ftr_namespace`),
  KEY `idx1289046_1` (`ftr_namespace`,`ftr_from`,`ftr_title`),
  KEY `idx1289052_4` (`ftr_from`,`ftr_title`,`ftr_namespace`),
  KEY `idx1289056_3` (`ftr_title`,`ftr_from`,`ftr_namespace`),
  KEY `idx1289074_1` (`ftr_namespace`,`ftr_title`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `flashapi_scores_best`
--

DROP TABLE IF EXISTS `flashapi_scores_best`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `flashapi_scores_best` (
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
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `flashapi_scores_best_2`
--

DROP TABLE IF EXISTS `flashapi_scores_best_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `flashapi_scores_best_2` (
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
  KEY `idx1289004_2` (`user_name`,`publisher_id`,`score_id`,`tag`,`archive_type`),
  KEY `idx1289010_5` (`archive_type`,`publisher_id`,`score_id`),
  KEY `idx1289022_2` (`user_id`,`tag`,`archive_type`,`score_id`,`publisher_id`),
  KEY `idx1289058_2` (`score_value`,`user_name`,`user_id`,`archive_type`,`score_id`,`tag`,`publisher_id`),
  KEY `idx1289072_3` (`tag`,`publisher_id`,`user_name`,`score_id`,`score_value`,`archive_type`),
  KEY `idx1289076_3` (`score_value`,`score_id`,`tag`,`user_name`,`user_id`,`archive_type`,`publisher_id`),
  KEY `idx1289084_2` (`score_id`,`user_id`,`user_name`),
  KEY `idx1289070_4` (`user_name`,`score_value`,`tag`,`publisher_id`,`score_id`,`archive_type`,`user_id`),
  KEY `idx1289100_3` (`publisher_id`,`user_id`,`score_value`,`archive_type`),
  KEY `idx1289106_4` (`score_value`,`tag`,`archive_type`,`score_id`,`user_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `iwlinks`
--

DROP TABLE IF EXISTS `iwlinks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `iwlinks` (
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
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `iwlinks_2`
--

DROP TABLE IF EXISTS `iwlinks_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `iwlinks_2` (
  `iwl_from` int(10) unsigned NOT NULL DEFAULT 0,
  `iwl_prefix` varbinary(20) NOT NULL DEFAULT '',
  `iwl_title` varbinary(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`iwl_from`,`iwl_prefix`,`iwl_title`),
  KEY `iwl_prefix_title_from` (`iwl_prefix`,`iwl_title`,`iwl_from`),
  KEY `iwl_prefix_from_title` (`iwl_prefix`,`iwl_from`,`iwl_title`),
  KEY `idx1289022_4` (`iwl_title`),
  KEY `idx1289082_1` (`iwl_prefix`,`iwl_from`),
  KEY `idx1289084_3` (`iwl_from`,`iwl_prefix`),
  KEY `idx1289096_1` (`iwl_title`,`iwl_prefix`,`iwl_from`),
  KEY `idx1289110_1` (`iwl_prefix`),
  KEY `idx1289124_1` (`iwl_prefix`,`iwl_title`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;


--
-- Table structure for table `recentchanges`
--

DROP TABLE IF EXISTS `recentchanges`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `recentchanges` (
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
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `recentchanges_2`
--

DROP TABLE IF EXISTS `recentchanges_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `recentchanges_2` (
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
  KEY `idx1289014_1` (`rc_this_oldid`,`rc_bot`,`rc_namespace`,`rc_new_len`,`rc_timestamp`),
  KEY `idx1289029_1` (`rc_old_len`,`rc_id`,`rc_type`,`rc_last_oldid`,`rc_source`,`rc_actor`,`rc_minor`,`rc_new_len`,`rc_bot`,`rc_cur_id`,`rc_ip`,`rc_logid`,`rc_patrolled`,`rc_this_oldid`),
  KEY `idx1289054_5` (`rc_log_type`,`rc_source`,`rc_deleted`,`rc_old_len`,`rc_new_len`,`rc_actor`,`rc_timestamp`,`rc_log_action`,`rc_minor`,`rc_this_oldid`,`rc_last_oldid`,`rc_type`,`rc_namespace`,`rc_bot`,`rc_logid`,`rc_ip`,`rc_new`),
  KEY `idx1289046_5` (`rc_ip`,`rc_log_type`,`rc_type`,`rc_new_len`,`rc_title`,`rc_comment_id`,`rc_deleted`,`rc_last_oldid`,`rc_cur_id`,`rc_old_len`),
  KEY `idx1289104_1` (`rc_timestamp`,`rc_namespace`,`rc_bot`,`rc_actor`,`rc_type`,`rc_deleted`,`rc_comment_id`,`rc_log_type`,`rc_new`,`rc_id`,`rc_source`,`rc_cur_id`,`rc_log_action`,`rc_logid`,`rc_new_len`)
) ENGINE=InnoDB AUTO_INCREMENT=5002 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `revision`
--

DROP TABLE IF EXISTS `revision`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `revision` (
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
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `revision_2`
--

DROP TABLE IF EXISTS `revision_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `revision_2` (
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
  KEY `idx1289000_5` (`rev_user_text`,`rev_sha1`,`rev_content_format`,`rev_deleted`,`rev_timestamp`,`rev_minor_edit`,`rev_user`),
  KEY `idx1289001_1` (`rev_id`,`rev_content_model`,`rev_len`),
  KEY `idx1289014_3` (`rev_user`,`rev_len`,`rev_content_format`,`rev_sha1`,`rev_minor_edit`,`rev_comment`,`rev_text_id`,`rev_user_text`,`rev_id`,`rev_page`,`rev_deleted`,`rev_content_model`,`rev_timestamp`,`rev_parent_id`),
  KEY `idx1289038_5` (`rev_deleted`,`rev_sha1`),
  KEY `idx1289042_2` (`rev_content_format`,`rev_timestamp`),
  KEY `idx1289064_4` (`rev_content_format`,`rev_user`,`rev_parent_id`,`rev_sha1`,`rev_id`,`rev_user_text`,`rev_text_id`,`rev_page`,`rev_len`,`rev_comment`,`rev_content_model`,`rev_minor_edit`,`rev_deleted`),
  KEY `idx1289076_1` (`rev_minor_edit`,`rev_comment`,`rev_deleted`,`rev_timestamp`,`rev_content_model`,`rev_len`,`rev_sha1`,`rev_id`,`rev_content_format`,`rev_user_text`,`rev_text_id`),
  KEY `idx1289076_4` (`rev_user_text`,`rev_minor_edit`,`rev_comment`,`rev_content_model`,`rev_deleted`,`rev_len`,`rev_parent_id`,`rev_timestamp`,`rev_text_id`,`rev_page`,`rev_id`,`rev_user`),
  KEY `idx1289066_4` (`rev_content_model`,`rev_id`,`rev_sha1`),
  KEY `idx1289090_1` (`rev_minor_edit`,`rev_sha1`,`rev_content_model`,`rev_text_id`,`rev_timestamp`,`rev_comment`,`rev_page`,`rev_deleted`,`rev_content_format`,`rev_len`,`rev_id`),
  KEY `idx1289082_4` (`rev_user`,`rev_len`,`rev_content_model`,`rev_text_id`,`rev_page`,`rev_deleted`,`rev_comment`),
  KEY `idx1289108_3` (`rev_minor_edit`)
) ENGINE=InnoDB AUTO_INCREMENT=5006 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `revision_comment_temp`
--

DROP TABLE IF EXISTS `revision_comment_temp`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `revision_comment_temp` (
  `revcomment_rev` int(10) unsigned NOT NULL,
  `revcomment_comment_id` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`revcomment_rev`,`revcomment_comment_id`),
  KEY `revcomment_rev` (`revcomment_rev`),
  KEY `revcomment_comment_id` (`revcomment_comment_id`),
  KEY `idx1289004_1` (`revcomment_comment_id`,`revcomment_rev`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `revision_comment_temp_2`
--

DROP TABLE IF EXISTS `revision_comment_temp_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `revision_comment_temp_2` (
  `revcomment_rev` int(10) unsigned NOT NULL,
  `revcomment_comment_id` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`revcomment_rev`,`revcomment_comment_id`),
  KEY `revcomment_rev` (`revcomment_rev`),
  KEY `revcomment_comment_id` (`revcomment_comment_id`),
  KEY `idx1289124_3` (`revcomment_comment_id`,`revcomment_rev`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `templatelinks`
--

DROP TABLE IF EXISTS `templatelinks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `templatelinks` (
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
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `templatelinks_2`
--

DROP TABLE IF EXISTS `templatelinks_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `templatelinks_2` (
  `tl_from` int(8) unsigned NOT NULL DEFAULT 0,
  `tl_namespace` int(11) NOT NULL DEFAULT 0,
  `tl_title` varbinary(255) NOT NULL DEFAULT '',
  `tl_from_namespace` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`tl_from`,`tl_namespace`,`tl_title`),
  KEY `tl_namespace` (`tl_namespace`,`tl_title`,`tl_from`),
  KEY `tl_backlinks_namespace` (`tl_from_namespace`,`tl_namespace`,`tl_title`,`tl_from`),
  KEY `idx1289008_1` (`tl_from_namespace`,`tl_namespace`,`tl_title`),
  KEY `idx1289008_3` (`tl_title`,`tl_from`,`tl_namespace`),
  KEY `idx1289014_2` (`tl_title`,`tl_from_namespace`,`tl_from`,`tl_namespace`),
  KEY `idx1289018_3` (`tl_title`),
  KEY `idx1289012_4` (`tl_from`,`tl_namespace`),
  KEY `idx1289022_1` (`tl_from_namespace`,`tl_from`),
  KEY `idx1289014_5` (`tl_title`,`tl_from_namespace`,`tl_from`),
  KEY `idx1289022_5` (`tl_namespace`,`tl_from`,`tl_from_namespace`),
  KEY `idx1289029_3` (`tl_title`,`tl_from`),
  KEY `idx1289032_5` (`tl_title`,`tl_from`,`tl_namespace`,`tl_from_namespace`),
  KEY `idx1289038_1` (`tl_title`,`tl_namespace`,`tl_from_namespace`,`tl_from`),
  KEY `idx1289052_1` (`tl_from_namespace`,`tl_namespace`,`tl_from`),
  KEY `idx1289060_5` (`tl_title`,`tl_namespace`),
  KEY `idx1289062_4` (`tl_from_namespace`),
  KEY `idx1289106_3` (`tl_from`),
  KEY `idx1289108_2` (`tl_namespace`),
  KEY `idx1289124_2` (`tl_namespace`,`tl_title`,`tl_from_namespace`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2021-05-29 20:45:11
-- MariaDB dump 10.19  Distrib 10.4.19-MariaDB, for Linux (x86_64)
--
-- Host: localhost    Database: db2
-- ------------------------------------------------------
-- Server version	10.4.19-MariaDB

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

CREATE DATABASE db2;
USE db2;

--
-- Table structure for table `tblname`
--

DROP TABLE IF EXISTS `tblname`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tblname` (
  `c01` int(8) NOT NULL AUTO_INCREMENT,
  `c02` varchar(8) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '',
  `c03` int(8) NOT NULL DEFAULT 0,
  `c04` varchar(24) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '',
  `c05` int(8) NOT NULL DEFAULT 0,
  `c06` bit(1) NOT NULL DEFAULT b'0',
  `c07` varchar(6) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '2020',
  `c08` smallint(4) NOT NULL DEFAULT 9999,
  `c09` varchar(16) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '',
  `c10` varchar(32) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '',
  `c11` bit(1) NOT NULL DEFAULT b'0',
  `c12` bit(1) NOT NULL DEFAULT b'0',
  `c13` bit(1) NOT NULL DEFAULT b'0',
  `c14` bit(1) NOT NULL DEFAULT b'0',
  `c15` bit(1) NOT NULL DEFAULT b'0',
  `c16` bit(1) NOT NULL DEFAULT b'0',
  `c17` bit(1) NOT NULL DEFAULT b'0',
  `c18` bit(1) NOT NULL DEFAULT b'0',
  `c19` bit(1) NOT NULL DEFAULT b'0',
  `c20` bit(1) NOT NULL DEFAULT b'0',
  PRIMARY KEY (`c01`),
  KEY `c03` (`c03`),
  KEY `c04` (`c04`),
  KEY `c05` (`c05`),
  KEY `x` (`c06`,`c07`,`c08`,`c09`,`c10`,`c11`,`c12`,`c13`,`c14`,`c15`,`c16`,`c17`,`c18`,`c19`,`c20`),
  KEY `idx1289008_4` (`c20`,`c11`,`c18`,`c13`,`c04`),
  KEY `idx1289008_5` (`c11`,`c02`,`c14`,`c16`,`c06`,`c20`,`c01`,`c04`,`c18`,`c05`,`c13`,`c10`,`c03`,`c12`,`c15`,`c08`,`c07`,`c09`),
  KEY `idx1289020_1` (`c08`,`c20`,`c18`,`c04`,`c01`,`c09`,`c15`,`c17`,`c03`,`c11`,`c07`,`c13`,`c12`,`c19`,`c14`,`c16`),
  KEY `idx1289020_2` (`c16`,`c01`,`c08`,`c20`,`c04`,`c09`),
  KEY `idx1289014_5` (`c07`,`c08`,`c13`,`c09`,`c19`,`c06`,`c15`,`c10`,`c01`,`c03`,`c05`,`c12`),
  KEY `idx1289042_4` (`c14`,`c05`,`c20`,`c10`,`c04`,`c17`,`c01`,`c09`,`c19`,`c18`,`c15`,`c16`,`c13`,`c06`,`c11`,`c02`,`c12`),
  KEY `idx1289084_5` (`c13`,`c07`,`c15`,`c01`,`c16`,`c08`,`c12`),
  KEY `idx1289040_4` (`c18`,`c15`,`c20`,`c03`,`c14`),
  KEY `idx1289090_3` (`c01`,`c10`,`c16`,`c09`,`c07`,`c11`,`c19`,`c15`,`c08`,`c06`,`c13`,`c20`,`c12`,`c14`,`c05`,`c17`,`c18`,`c02`,`c04`),
  KEY `idx1289040_5` (`c03`,`c11`,`c09`,`c19`,`c08`,`c02`,`c01`,`c06`,`c10`,`c17`,`c04`,`c14`,`c05`,`c12`,`c13`,`c20`,`c18`),
  KEY `idx1289100_2` (`c17`,`c11`,`c10`,`c03`,`c15`,`c08`,`c14`,`c02`,`c12`,`c07`,`c05`,`c04`,`c01`,`c20`,`c16`,`c06`,`c09`,`c13`,`c18`),
  KEY `idx1289062_5` (`c12`,`c08`,`c14`,`c01`,`c11`,`c18`,`c16`,`c13`,`c15`,`c02`,`c19`,`c04`,`c06`,`c03`,`c05`,`c17`,`c10`,`c09`,`c07`)
) ENGINE=InnoDB AUTO_INCREMENT=5004 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `tblname_2`
--

DROP TABLE IF EXISTS `tblname_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `tblname_2` (
  `c01` int(8) NOT NULL AUTO_INCREMENT,
  `c02` varchar(8) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '',
  `c03` int(8) NOT NULL DEFAULT 0,
  `c04` varchar(24) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '',
  `c05` int(8) NOT NULL DEFAULT 0,
  `c06` bit(1) NOT NULL DEFAULT b'0',
  `c07` varchar(6) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '2020',
  `c08` smallint(4) NOT NULL DEFAULT 9999,
  `c09` varchar(16) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '',
  `c10` varchar(32) CHARACTER SET latin1 COLLATE latin1_bin NOT NULL DEFAULT '',
  `c11` bit(1) NOT NULL DEFAULT b'0',
  `c12` bit(1) NOT NULL DEFAULT b'0',
  `c13` bit(1) NOT NULL DEFAULT b'0',
  `c14` bit(1) NOT NULL DEFAULT b'0',
  `c15` bit(1) NOT NULL DEFAULT b'0',
  `c16` bit(1) NOT NULL DEFAULT b'0',
  `c17` bit(1) NOT NULL DEFAULT b'0',
  `c18` bit(1) NOT NULL DEFAULT b'0',
  `c19` bit(1) NOT NULL DEFAULT b'0',
  `c20` bit(1) NOT NULL DEFAULT b'0',
  PRIMARY KEY (`c01`),
  KEY `c03` (`c03`),
  KEY `c04` (`c04`),
  KEY `c05` (`c05`),
  KEY `x` (`c06`,`c07`,`c08`,`c09`,`c10`,`c11`,`c12`,`c13`,`c14`,`c15`,`c16`,`c17`,`c18`,`c19`,`c20`),
  KEY `idx1289004_3` (`c13`,`c02`),
  KEY `idx1289004_4` (`c01`,`c12`,`c04`,`c07`,`c03`,`c16`,`c18`,`c09`,`c05`,`c15`,`c02`,`c13`),
  KEY `idx1289008_3` (`c16`),
  KEY `idx1289022_4` (`c05`,`c16`,`c04`,`c18`,`c10`,`c12`,`c11`,`c08`,`c17`,`c07`,`c20`),
  KEY `idx1289032_1` (`c02`,`c10`),
  KEY `idx1289036_2` (`c05`,`c14`,`c07`,`c06`,`c01`),
  KEY `idx1289056_2` (`c13`,`c18`,`c12`,`c11`,`c03`,`c19`,`c15`,`c17`,`c14`,`c01`,`c10`,`c08`,`c02`,`c04`,`c06`,`c07`,`c09`,`c16`,`c20`),
  KEY `idx1289076_4` (`c01`,`c17`,`c16`,`c05`,`c15`,`c10`,`c04`,`c20`,`c18`,`c06`,`c12`,`c02`,`c11`,`c09`,`c07`,`c03`,`c08`,`c19`,`c13`),
  KEY `idx1289072_2` (`c18`,`c17`,`c09`,`c01`,`c07`,`c11`,`c13`,`c06`,`c14`,`c04`,`c20`,`c02`,`c15`,`c08`,`c16`,`c12`,`c05`,`c19`,`c03`),
  KEY `idx1289042_5` (`c07`,`c09`,`c18`,`c05`,`c14`,`c11`,`c17`,`c13`,`c19`,`c10`),
  KEY `idx1289104_1` (`c12`,`c16`,`c19`,`c15`,`c06`,`c11`,`c09`,`c01`,`c03`),
  KEY `idx1289074_3` (`c04`,`c05`,`c06`,`c02`,`c01`),
  KEY `idx1289062_4` (`c20`,`c03`,`c05`,`c16`,`c14`,`c15`,`c01`,`c08`)
) ENGINE=InnoDB AUTO_INCREMENT=5003 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `categorylinks`
--

DROP TABLE IF EXISTS `categorylinks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `categorylinks` (
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
  KEY `idx1289000_2` (`cl_to`,`cl_type`,`cl_sortkey`,`cl_from`,`cl_collation`,`cl_sortkey_prefix`,`cl_timestamp`),
  KEY `idx1289006_2` (`cl_type`,`cl_sortkey`,`cl_to`,`cl_timestamp`),
  KEY `idx1289016_1` (`cl_to`,`cl_timestamp`,`cl_collation`,`cl_sortkey_prefix`),
  KEY `idx1289018_3` (`cl_to`,`cl_sortkey`,`cl_from`,`cl_type`,`cl_sortkey_prefix`,`cl_collation`),
  KEY `idx1289016_2` (`cl_collation`,`cl_to`,`cl_from`,`cl_timestamp`),
  KEY `idx1289018_5` (`cl_from`,`cl_type`,`cl_timestamp`,`cl_sortkey`,`cl_to`,`cl_collation`),
  KEY `idx1289022_3` (`cl_timestamp`,`cl_from`,`cl_sortkey_prefix`,`cl_collation`,`cl_to`,`cl_type`),
  KEY `idx1289020_4` (`cl_to`,`cl_sortkey_prefix`),
  KEY `idx1289038_2` (`cl_type`,`cl_to`,`cl_sortkey_prefix`),
  KEY `idx1289042_2` (`cl_timestamp`,`cl_collation`),
  KEY `idx1289048_2` (`cl_type`,`cl_sortkey_prefix`,`cl_to`,`cl_timestamp`),
  KEY `idx1289046_3` (`cl_from`,`cl_sortkey_prefix`,`cl_to`,`cl_timestamp`,`cl_collation`),
  KEY `idx1289090_2` (`cl_timestamp`,`cl_from`,`cl_collation`,`cl_type`),
  KEY `idx1289054_3` (`cl_collation`,`cl_timestamp`,`cl_from`,`cl_sortkey`,`cl_sortkey_prefix`),
  KEY `idx1289092_2` (`cl_timestamp`,`cl_from`,`cl_collation`,`cl_to`,`cl_sortkey_prefix`,`cl_sortkey`),
  KEY `idx1289096_2` (`cl_sortkey_prefix`,`cl_from`,`cl_collation`,`cl_type`),
  KEY `idx1289096_3` (`cl_collation`),
  KEY `idx1289074_1` (`cl_from`,`cl_sortkey_prefix`,`cl_to`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `categorylinks_2`
--

DROP TABLE IF EXISTS `categorylinks_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `categorylinks_2` (
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
  KEY `idx1289004_1` (`cl_collation`),
  KEY `idx1289008_1` (`cl_from`,`cl_sortkey`,`cl_timestamp`,`cl_collation`,`cl_to`,`cl_sortkey_prefix`,`cl_type`),
  KEY `idx1289012_5` (`cl_sortkey_prefix`,`cl_collation`,`cl_timestamp`,`cl_sortkey`,`cl_from`),
  KEY `idx1289027_5` (`cl_timestamp`,`cl_sortkey`,`cl_collation`,`cl_to`,`cl_sortkey_prefix`),
  KEY `idx1289040_2` (`cl_type`,`cl_from`,`cl_sortkey`,`cl_to`),
  KEY `idx1289072_1` (`cl_from`,`cl_sortkey`,`cl_to`,`cl_collation`,`cl_sortkey_prefix`,`cl_timestamp`),
  KEY `idx1289066_1` (`cl_to`),
  KEY `idx1289090_1` (`cl_type`,`cl_sortkey_prefix`,`cl_to`,`cl_sortkey`,`cl_timestamp`),
  KEY `idx1289082_4` (`cl_sortkey_prefix`,`cl_type`,`cl_sortkey`,`cl_from`,`cl_collation`),
  KEY `idx1289092_1` (`cl_sortkey_prefix`,`cl_type`,`cl_to`,`cl_sortkey`,`cl_from`,`cl_timestamp`,`cl_collation`),
  KEY `idx1289056_5` (`cl_type`),
  KEY `idx1289052_2` (`cl_timestamp`,`cl_from`,`cl_sortkey`,`cl_to`),
  KEY `idx1289090_5` (`cl_sortkey`,`cl_timestamp`,`cl_collation`,`cl_type`,`cl_from`,`cl_sortkey_prefix`),
  KEY `idx1289074_2` (`cl_sortkey_prefix`,`cl_collation`,`cl_sortkey`,`cl_timestamp`,`cl_type`,`cl_from`,`cl_to`),
  KEY `idx1289066_3` (`cl_timestamp`,`cl_sortkey`,`cl_to`,`cl_type`,`cl_sortkey_prefix`,`cl_collation`,`cl_from`),
  KEY `idx1289066_4` (`cl_to`,`cl_sortkey_prefix`,`cl_timestamp`,`cl_collation`,`cl_sortkey`,`cl_from`),
  KEY `idx1289068_2` (`cl_sortkey_prefix`,`cl_timestamp`,`cl_collation`,`cl_from`,`cl_type`,`cl_to`,`cl_sortkey`),
  KEY `idx1289108_1` (`cl_sortkey`,`cl_from`,`cl_type`,`cl_timestamp`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `flaggedrevs_tracking`
--

DROP TABLE IF EXISTS `flaggedrevs_tracking`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `flaggedrevs_tracking` (
  `ftr_from` int(10) unsigned NOT NULL DEFAULT 0,
  `ftr_namespace` int(11) NOT NULL DEFAULT 0,
  `ftr_title` varbinary(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`ftr_from`),
  KEY `from_namespace_title` (`ftr_from`,`ftr_namespace`,`ftr_title`),
  KEY `namespace_title_from` (`ftr_namespace`,`ftr_title`,`ftr_from`),
  KEY `idx1289008_2` (`ftr_title`),
  KEY `idx1289038_5` (`ftr_from`,`ftr_title`),
  KEY `idx1289056_3` (`ftr_namespace`,`ftr_from`,`ftr_title`),
  KEY `idx1289072_3` (`ftr_title`,`ftr_namespace`,`ftr_from`),
  KEY `idx1289062_3` (`ftr_namespace`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `flaggedrevs_tracking_2`
--

DROP TABLE IF EXISTS `flaggedrevs_tracking_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `flaggedrevs_tracking_2` (
  `ftr_from` int(10) unsigned NOT NULL DEFAULT 0,
  `ftr_namespace` int(11) NOT NULL DEFAULT 0,
  `ftr_title` varbinary(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`ftr_from`),
  KEY `from_namespace_title` (`ftr_from`,`ftr_namespace`,`ftr_title`),
  KEY `namespace_title_from` (`ftr_namespace`,`ftr_title`,`ftr_from`),
  KEY `idx1289001_5` (`ftr_from`,`ftr_namespace`),
  KEY `idx1289002_2` (`ftr_title`,`ftr_from`,`ftr_namespace`),
  KEY `idx1289012_1` (`ftr_title`,`ftr_namespace`),
  KEY `idx1289034_5` (`ftr_namespace`,`ftr_from`,`ftr_title`),
  KEY `idx1289042_1` (`ftr_namespace`),
  KEY `idx1289054_2` (`ftr_title`,`ftr_from`),
  KEY `idx1289070_5` (`ftr_title`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `flashapi_scores_best`
--

DROP TABLE IF EXISTS `flashapi_scores_best`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `flashapi_scores_best` (
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
  KEY `idx1289002_4` (`publisher_id`,`tag`,`score_value`),
  KEY `idx1289012_3` (`publisher_id`,`score_value`,`tag`,`user_id`,`score_id`),
  KEY `idx1289022_5` (`tag`,`user_name`,`archive_type`,`publisher_id`),
  KEY `idx1289029_4` (`score_id`,`score_value`,`publisher_id`,`archive_type`,`user_id`,`tag`),
  KEY `idx1289034_1` (`score_id`,`user_id`,`publisher_id`),
  KEY `idx1289046_2` (`score_value`,`publisher_id`,`archive_type`,`user_id`,`tag`),
  KEY `idx1289064_1` (`tag`,`user_name`),
  KEY `idx1289064_2` (`publisher_id`,`archive_type`,`user_name`,`score_id`,`tag`,`score_value`,`user_id`),
  KEY `idx1289040_1` (`archive_type`,`tag`,`publisher_id`,`score_id`,`user_name`,`user_id`,`score_value`),
  KEY `idx1289084_2` (`publisher_id`),
  KEY `idx1289084_3` (`tag`,`user_id`,`archive_type`,`user_name`,`score_value`,`publisher_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `flashapi_scores_best_2`
--

DROP TABLE IF EXISTS `flashapi_scores_best_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `flashapi_scores_best_2` (
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
  KEY `idx1289006_3` (`score_id`,`tag`,`archive_type`,`user_name`),
  KEY `idx1289010_2` (`user_id`),
  KEY `idx1289016_5` (`user_name`,`score_id`,`score_value`,`archive_type`,`user_id`),
  KEY `idx1289014_2` (`user_name`,`publisher_id`,`score_id`,`tag`),
  KEY `idx1289038_1` (`publisher_id`,`user_name`,`archive_type`,`score_id`,`user_id`,`tag`),
  KEY `idx1289044_3` (`user_id`,`score_id`,`user_name`,`archive_type`),
  KEY `idx1289060_1` (`score_value`,`archive_type`,`user_name`,`tag`,`score_id`),
  KEY `idx1289076_5` (`score_value`,`tag`,`publisher_id`,`archive_type`,`user_id`),
  KEY `idx1289040_3` (`score_id`,`user_name`,`tag`,`archive_type`,`user_id`),
  KEY `idx1289070_1` (`score_id`,`publisher_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `iwlinks`
--

DROP TABLE IF EXISTS `iwlinks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `iwlinks` (
  `iwl_from` int(10) unsigned NOT NULL DEFAULT 0,
  `iwl_prefix` varbinary(20) NOT NULL DEFAULT '',
  `iwl_title` varbinary(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`iwl_from`,`iwl_prefix`,`iwl_title`),
  KEY `iwl_prefix_title_from` (`iwl_prefix`,`iwl_title`,`iwl_from`),
  KEY `iwl_prefix_from_title` (`iwl_prefix`,`iwl_from`,`iwl_title`),
  KEY `idx1289000_3` (`iwl_title`),
  KEY `idx1289082_1` (`iwl_prefix`,`iwl_from`),
  KEY `idx1289052_4` (`iwl_from`),
  KEY `idx1289070_2` (`iwl_from`,`iwl_title`,`iwl_prefix`),
  KEY `idx1289050_4` (`iwl_title`,`iwl_prefix`,`iwl_from`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `iwlinks_2`
--

DROP TABLE IF EXISTS `iwlinks_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `iwlinks_2` (
  `iwl_from` int(10) unsigned NOT NULL DEFAULT 0,
  `iwl_prefix` varbinary(20) NOT NULL DEFAULT '',
  `iwl_title` varbinary(255) NOT NULL DEFAULT '',
  PRIMARY KEY (`iwl_from`,`iwl_prefix`,`iwl_title`),
  KEY `iwl_prefix_title_from` (`iwl_prefix`,`iwl_title`,`iwl_from`),
  KEY `iwl_prefix_from_title` (`iwl_prefix`,`iwl_from`,`iwl_title`),
  KEY `idx1289001_2` (`iwl_prefix`,`iwl_from`),
  KEY `idx1289029_1` (`iwl_prefix`),
  KEY `idx1289056_1` (`iwl_title`,`iwl_prefix`),
  KEY `idx1289056_4` (`iwl_from`,`iwl_prefix`),
  KEY `idx1289066_2` (`iwl_from`),
  KEY `idx1289054_4` (`iwl_from`,`iwl_title`),
  KEY `idx1289062_1` (`iwl_title`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;


--
-- Table structure for table `recentchanges`
--

DROP TABLE IF EXISTS `recentchanges`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `recentchanges` (
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
  KEY `idx1289029_2` (`rc_patrolled`,`rc_title`,`rc_type`,`rc_this_oldid`,`rc_actor`,`rc_log_action`,`rc_ip`,`rc_log_type`,`rc_cur_id`,`rc_new`,`rc_old_len`,`rc_namespace`,`rc_timestamp`,`rc_minor`),
  KEY `idx1289044_1` (`rc_new`,`rc_id`,`rc_type`,`rc_cur_id`,`rc_source`,`rc_old_len`,`rc_logid`,`rc_title`,`rc_log_type`),
  KEY `idx1289048_4` (`rc_bot`,`rc_cur_id`,`rc_deleted`,`rc_log_action`,`rc_actor`,`rc_source`,`rc_type`,`rc_ip`),
  KEY `idx1289096_4` (`rc_type`,`rc_timestamp`,`rc_cur_id`,`rc_minor`,`rc_this_oldid`,`rc_source`,`rc_last_oldid`,`rc_logid`,`rc_title`,`rc_patrolled`,`rc_bot`,`rc_actor`,`rc_ip`,`rc_log_action`),
  KEY `idx1289070_3` (`rc_source`,`rc_new`,`rc_log_action`,`rc_patrolled`,`rc_new_len`,`rc_timestamp`,`rc_log_type`,`rc_minor`,`rc_logid`,`rc_type`,`rc_deleted`,`rc_namespace`,`rc_last_oldid`,`rc_id`,`rc_title`),
  KEY `idx1289062_2` (`rc_bot`,`rc_new`,`rc_new_len`,`rc_log_action`,`rc_timestamp`,`rc_deleted`,`rc_logid`,`rc_type`,`rc_id`,`rc_last_oldid`)
) ENGINE=InnoDB AUTO_INCREMENT=5003 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `recentchanges_2`
--

DROP TABLE IF EXISTS `recentchanges_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `recentchanges_2` (
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
  KEY `idx1289018_2` (`rc_new_len`,`rc_this_oldid`,`rc_ip`,`rc_comment_id`,`rc_deleted`,`rc_timestamp`,`rc_type`),
  KEY `idx1289024_3` (`rc_title`,`rc_ip`,`rc_last_oldid`,`rc_namespace`,`rc_new`,`rc_timestamp`,`rc_id`,`rc_minor`,`rc_this_oldid`,`rc_bot`,`rc_source`,`rc_patrolled`,`rc_type`,`rc_comment_id`,`rc_old_len`,`rc_logid`),
  KEY `idx1289052_1` (`rc_last_oldid`,`rc_new_len`,`rc_this_oldid`,`rc_cur_id`,`rc_source`,`rc_title`,`rc_patrolled`,`rc_type`,`rc_new`,`rc_log_type`,`rc_logid`,`rc_old_len`,`rc_namespace`,`rc_ip`,`rc_timestamp`,`rc_actor`,`rc_minor`,`rc_bot`,`rc_deleted`),
  KEY `idx1289050_3` (`rc_log_type`,`rc_new_len`,`rc_id`,`rc_patrolled`,`rc_comment_id`,`rc_new`,`rc_this_oldid`,`rc_minor`,`rc_type`,`rc_actor`,`rc_namespace`,`rc_deleted`,`rc_last_oldid`,`rc_cur_id`,`rc_timestamp`,`rc_ip`),
  KEY `idx1289058_1` (`rc_new`,`rc_cur_id`,`rc_minor`,`rc_deleted`,`rc_comment_id`,`rc_this_oldid`,`rc_patrolled`,`rc_actor`,`rc_logid`,`rc_source`,`rc_type`,`rc_log_type`,`rc_old_len`,`rc_timestamp`,`rc_bot`,`rc_title`,`rc_log_action`,`rc_new_len`,`rc_ip`,`rc_id`),
  KEY `idx1289060_5` (`rc_deleted`,`rc_actor`,`rc_minor`),
  KEY `idx1289064_4` (`rc_source`,`rc_patrolled`,`rc_id`,`rc_title`,`rc_comment_id`,`rc_log_action`,`rc_minor`,`rc_new`,`rc_deleted`,`rc_last_oldid`,`rc_cur_id`,`rc_this_oldid`,`rc_timestamp`,`rc_old_len`,`rc_type`,`rc_bot`,`rc_ip`,`rc_new_len`,`rc_log_type`)
) ENGINE=InnoDB AUTO_INCREMENT=5163 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `revision`
--

DROP TABLE IF EXISTS `revision`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `revision` (
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
  KEY `idx1289001_3` (`rev_deleted`,`rev_len`,`rev_page`,`rev_sha1`,`rev_text_id`,`rev_parent_id`,`rev_user_text`,`rev_content_model`),
  KEY `idx1289001_4` (`rev_content_format`,`rev_len`,`rev_user_text`,`rev_deleted`,`rev_content_model`,`rev_user`,`rev_id`,`rev_page`,`rev_minor_edit`,`rev_sha1`,`rev_text_id`,`rev_timestamp`,`rev_comment`,`rev_parent_id`),
  KEY `idx1289020_3` (`rev_page`,`rev_sha1`,`rev_user_text`,`rev_content_format`,`rev_deleted`,`rev_content_model`,`rev_comment`),
  KEY `idx1289010_4` (`rev_id`,`rev_timestamp`,`rev_user_text`,`rev_user`,`rev_page`,`rev_comment`,`rev_len`,`rev_content_format`,`rev_content_model`),
  KEY `idx1289020_5` (`rev_content_format`,`rev_id`,`rev_text_id`,`rev_len`,`rev_sha1`),
  KEY `idx1289076_3` (`rev_parent_id`,`rev_len`,`rev_user_text`,`rev_timestamp`,`rev_content_format`,`rev_id`,`rev_minor_edit`),
  KEY `idx1289072_4` (`rev_minor_edit`,`rev_user`,`rev_content_format`,`rev_id`,`rev_page`,`rev_len`,`rev_parent_id`,`rev_timestamp`,`rev_deleted`,`rev_text_id`),
  KEY `idx1289060_4` (`rev_text_id`,`rev_content_model`,`rev_deleted`,`rev_comment`,`rev_minor_edit`,`rev_user_text`,`rev_sha1`,`rev_page`,`rev_parent_id`,`rev_len`,`rev_user`,`rev_timestamp`,`rev_id`),
  KEY `idx1289072_5` (`rev_len`,`rev_user`,`rev_content_model`,`rev_sha1`,`rev_id`,`rev_content_format`,`rev_user_text`,`rev_page`,`rev_comment`,`rev_deleted`,`rev_minor_edit`,`rev_text_id`,`rev_parent_id`),
  KEY `idx1289090_4` (`rev_content_format`,`rev_timestamp`,`rev_minor_edit`,`rev_comment`,`rev_id`),
  KEY `idx1289092_3` (`rev_content_model`,`rev_content_format`,`rev_minor_edit`,`rev_page`,`rev_sha1`),
  KEY `idx1289054_5` (`rev_len`,`rev_deleted`,`rev_timestamp`,`rev_content_format`)
) ENGINE=InnoDB AUTO_INCREMENT=5002 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `revision_2`
--

DROP TABLE IF EXISTS `revision_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `revision_2` (
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
  KEY `idx1289000_5` (`rev_id`,`rev_comment`,`rev_content_format`),
  KEY `idx1289004_2` (`rev_sha1`,`rev_id`),
  KEY `idx1289018_1` (`rev_user_text`,`rev_len`),
  KEY `idx1289027_2` (`rev_user_text`,`rev_content_model`),
  KEY `idx1289044_2` (`rev_parent_id`,`rev_user_text`,`rev_content_model`,`rev_sha1`,`rev_user`,`rev_deleted`,`rev_id`,`rev_timestamp`,`rev_text_id`,`rev_len`,`rev_page`,`rev_minor_edit`,`rev_comment`),
  KEY `idx1289076_1` (`rev_parent_id`,`rev_content_model`,`rev_timestamp`,`rev_id`,`rev_comment`,`rev_user`,`rev_deleted`,`rev_text_id`,`rev_minor_edit`),
  KEY `idx1289076_2` (`rev_len`,`rev_user_text`,`rev_parent_id`,`rev_sha1`,`rev_text_id`,`rev_minor_edit`,`rev_id`),
  KEY `idx1289084_4` (`rev_user`,`rev_sha1`,`rev_deleted`,`rev_text_id`,`rev_user_text`,`rev_timestamp`,`rev_len`,`rev_page`,`rev_content_model`),
  KEY `idx1289068_1` (`rev_text_id`,`rev_user_text`)
) ENGINE=InnoDB AUTO_INCREMENT=5287 DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `revision_comment_temp`
--

DROP TABLE IF EXISTS `revision_comment_temp`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `revision_comment_temp` (
  `revcomment_rev` int(10) unsigned NOT NULL,
  `revcomment_comment_id` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`revcomment_rev`,`revcomment_comment_id`),
  KEY `revcomment_rev` (`revcomment_rev`),
  KEY `revcomment_comment_id` (`revcomment_comment_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `revision_comment_temp_2`
--

DROP TABLE IF EXISTS `revision_comment_temp_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `revision_comment_temp_2` (
  `revcomment_rev` int(10) unsigned NOT NULL,
  `revcomment_comment_id` bigint(20) unsigned NOT NULL,
  PRIMARY KEY (`revcomment_rev`,`revcomment_comment_id`),
  KEY `revcomment_rev` (`revcomment_rev`),
  KEY `revcomment_comment_id` (`revcomment_comment_id`),
  KEY `idx1289060_2` (`revcomment_comment_id`,`revcomment_rev`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `templatelinks`
--

DROP TABLE IF EXISTS `templatelinks`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `templatelinks` (
  `tl_from` int(8) unsigned NOT NULL DEFAULT 0,
  `tl_namespace` int(11) NOT NULL DEFAULT 0,
  `tl_title` varbinary(255) NOT NULL DEFAULT '',
  `tl_from_namespace` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`tl_from`,`tl_namespace`,`tl_title`),
  KEY `tl_namespace` (`tl_namespace`,`tl_title`,`tl_from`),
  KEY `tl_backlinks_namespace` (`tl_from_namespace`,`tl_namespace`,`tl_title`,`tl_from`),
  KEY `idx1289006_5` (`tl_from`,`tl_from_namespace`,`tl_namespace`),
  KEY `idx1289032_2` (`tl_namespace`,`tl_title`,`tl_from_namespace`),
  KEY `idx1289038_3` (`tl_from`,`tl_title`,`tl_from_namespace`),
  KEY `idx1289036_3` (`tl_namespace`,`tl_title`),
  KEY `idx1289048_1` (`tl_from_namespace`,`tl_namespace`,`tl_title`),
  KEY `idx1289046_4` (`tl_title`),
  KEY `idx1289060_3` (`tl_from_namespace`,`tl_namespace`,`tl_from`,`tl_title`),
  KEY `idx1289096_5` (`tl_from`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Table structure for table `templatelinks_2`
--

DROP TABLE IF EXISTS `templatelinks_2`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!40101 SET character_set_client = utf8 */;
CREATE TABLE `templatelinks_2` (
  `tl_from` int(8) unsigned NOT NULL DEFAULT 0,
  `tl_namespace` int(11) NOT NULL DEFAULT 0,
  `tl_title` varbinary(255) NOT NULL DEFAULT '',
  `tl_from_namespace` int(11) NOT NULL DEFAULT 0,
  PRIMARY KEY (`tl_from`,`tl_namespace`,`tl_title`),
  KEY `tl_namespace` (`tl_namespace`,`tl_title`,`tl_from`),
  KEY `tl_backlinks_namespace` (`tl_from_namespace`,`tl_namespace`,`tl_title`,`tl_from`),
  KEY `idx1289000_4` (`tl_title`),
  KEY `idx1289004_5` (`tl_from`,`tl_from_namespace`),
  KEY `idx1289022_1` (`tl_title`,`tl_from`),
  KEY `idx1289010_5` (`tl_title`,`tl_from`,`tl_from_namespace`),
  KEY `idx1289024_1` (`tl_from`,`tl_namespace`),
  KEY `idx1289014_4` (`tl_from`,`tl_title`,`tl_from_namespace`),
  KEY `idx1289036_1` (`tl_from_namespace`,`tl_title`,`tl_from`,`tl_namespace`),
  KEY `idx1289036_5` (`tl_title`,`tl_from_namespace`,`tl_from`),
  KEY `idx1289082_2` (`tl_title`,`tl_namespace`,`tl_from`),
  KEY `idx1289082_3` (`tl_from`,`tl_title`,`tl_from_namespace`,`tl_namespace`),
  KEY `idx1289082_5` (`tl_from`,`tl_from_namespace`,`tl_title`,`tl_namespace`),
  KEY `idx1289096_1` (`tl_namespace`,`tl_from_namespace`,`tl_title`,`tl_from`),
  KEY `idx1289058_2` (`tl_namespace`),
  KEY `idx1289104_2` (`tl_namespace`,`tl_from_namespace`),
  KEY `idx1289068_3` (`tl_from_namespace`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;
/*!40101 SET character_set_client = @saved_cs_client */;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2021-05-29 20:45:18
