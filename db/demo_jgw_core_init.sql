-- MySQL dump 10.13  Distrib 5.1.69, for redhat-linux-gnu (i386)
--
-- Host: localhost    Database: development_jgw_core
-- ------------------------------------------------------
-- Server version	5.1.69

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;
SET SQL_MODE="NO_AUTO_VALUE_ON_ZERO";

--
-- Dumping data for table `intra_maintenances`
--


--
-- Dumping data for table `intra_messages`
--


--
-- Dumping data for table `schema_migrations`
--


--
-- Dumping data for table `sessions`
--


--
-- Dumping data for table `system_admin_logs`
--


--
-- Dumping data for table `system_authorizations`
--


--
-- Dumping data for table `system_commitments`
--


--
-- Dumping data for table `system_creators`
--


--
-- Dumping data for table `system_custom_group_roles`
--


--
-- Dumping data for table `system_custom_groups`
--


--
-- Dumping data for table `system_group_change_pickups`
--

--
-- Dumping data for table `system_group_changes`
--


--
-- Dumping data for table `system_group_histories`
--

LOCK TABLES `system_group_histories` WRITE;
/*!40000 ALTER TABLE `system_group_histories` DISABLE KEYS */;
INSERT INTO `system_group_histories` (`id`, `parent_id`, `state`, `created_at`, `updated_at`, `level_no`, `version_id`, `code`, `name`, `name_en`, `email`, `start_at`, `end_at`, `sort_no`, `ldap_version`, `ldap`) VALUES 
(100,1,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00',2,1,'SYSTEM','システム管理','','','2014-01-01 00:00:00',NULL,999999999,NULL,1),
(110,1,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00',2,1,'999000','市長・副市長','','','2014-01-01 00:00:00',NULL,1000,NULL,1),
(111,110,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00',3,1,'999001','市長・副市長','','','2014-01-01 00:00:00',NULL,1010,NULL,1),
(120,1,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00',2,1,'010000','政策部','','','2014-01-01 00:00:00',NULL,2000,NULL,1),
(121,120,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00',3,1,'010010','政策企画課','','','2014-01-01 00:00:00',NULL,2010,NULL,1),
(122,120,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00',3,1,'010020','秘書広報課','','','2014-01-01 00:00:00',NULL,2020,NULL,1),
(123,120,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00',3,1,'010530','情報政策課','','','2014-01-01 00:00:00',NULL,2030,NULL,1),
(130,1,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00',2,1,'500000','出納室','','','2014-01-01 00:00:00',NULL,3000,NULL,1),
(131,130,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00',3,1,'500010','出納室','','','2014-01-01 00:00:00',NULL,3010,NULL,1);
/*!40000 ALTER TABLE `system_group_histories` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `system_group_history_temporaries`
--


--
-- Dumping data for table `system_group_nexts`
--


--
-- Dumping data for table `system_group_temporaries`
--


--
-- Dumping data for table `system_group_updates`
--


--
-- Dumping data for table `system_group_versions`
--


--
-- Dumping data for table `system_groups`
--

LOCK TABLES `system_groups` WRITE;
/*!40000 ALTER TABLE `system_groups` DISABLE KEYS */;
INSERT INTO `system_groups` (`id`, `parent_id`, `state`, `created_at`, `updated_at`, `level_no`, `version_id`, `code`, `name`, `name_en`, `email`, `start_at`, `end_at`, `sort_no`, `ldap_version`, `ldap`, `category`) VALUES 
(1,0,'enabled','2009-04-01 00:00:00','2009-10-22 16:00:00',1,1,'1','root','','','2009-04-01 00:00:00',NULL,0,NULL,0,NULL),
(100,1,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00',2,1,'SYSTEM','システム管理','','','2014-01-01 00:00:00',NULL,999999999,NULL,1,0),
(110,1,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00',2,1,'999000','地方自治長','','','2014-01-01 00:00:00',NULL,1000,NULL,1,0),
(111,110,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00',3,1,'999001','地方自治長','','','2014-01-01 00:00:00',NULL,1010,NULL,1,0),
(120,1,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00',2,1,'010000','総務部','','','2014-01-01 00:00:00',NULL,2000,NULL,1,0),
(121,120,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00',3,1,'010010','総務課','','','2014-01-01 00:00:00',NULL,2010,NULL,1,0),
(122,120,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00',3,1,'010020','秘書広報課','','','2014-01-01 00:00:00',NULL,2020,NULL,1,0),
(123,120,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00',3,1,'010530','情報企画課','','','2014-01-01 00:00:00',NULL,2030,NULL,1,0),
(130,1,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00',2,1,'500000','出納室','','','2014-01-01 00:00:00',NULL,3000,NULL,1,0),
(131,130,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00',3,1,'500010','出納室','','','2014-01-01 00:00:00',NULL,3010,NULL,1,0);
/*!40000 ALTER TABLE `system_groups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `system_idconversions`
--


--
-- Dumping data for table `system_inquiries`
--


--
-- Dumping data for table `system_languages`
--

LOCK TABLES `system_languages` WRITE;
/*!40000 ALTER TABLE `system_languages` DISABLE KEYS */;
INSERT INTO `system_languages` (`id`, `state`, `created_at`, `updated_at`, `sort_no`, `name`, `title`) VALUES 
(1,'enabled','2008-01-01 00:00:00','2008-01-01 00:00:00',1,'japanese','日本語'),
(2,'enabled','2008-01-01 00:00:00','2008-01-01 00:00:00',2,'english','英語'),
(3,'enabled','2008-01-01 00:00:00','2008-01-01 00:00:00',3,'chinese','中国語'),
(4,'enabled','2008-01-01 00:00:00','2008-01-01 00:00:00',4,'korean','韓国語'),
(5,'enabled','2008-01-01 00:00:00','2008-01-01 00:00:00',5,'German','ドイツ語');
/*!40000 ALTER TABLE `system_languages` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `system_ldap_temporaries`
--


--
-- Dumping data for table `system_login_logs`
--


--
-- Dumping data for table `system_maps`
--


--
-- Dumping data for table `system_priv_names`
--

LOCK TABLES `system_priv_names` WRITE;
/*!40000 ALTER TABLE `system_priv_names` DISABLE KEYS */;
INSERT INTO `system_priv_names` (`id`, `unid`, `state`, `content_id`, `created_at`, `updated_at`, `display_name`, `priv_name`, `sort_no`) VALUES 
(1,NULL,'public',NULL,'2010-08-02 17:50:15','2010-08-03 10:39:55','管理者','admin',0),
(2,NULL,'closed',NULL,'2010-08-02 17:59:07','2010-08-17 20:52:42','開発者','developer',2),
(8,NULL,'public',NULL,'2010-08-04 10:03:32','2010-08-04 10:03:32','全庁予定登録者','schedule_pref_admin',2),
(10,NULL,'public',NULL,'2010-09-29 13:49:24','2014-01-27 17:48:18','運用管理者','editor',30);
/*!40000 ALTER TABLE `system_priv_names` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `system_public_logs`
--

LOCK TABLES `system_public_logs` WRITE;
/*!40000 ALTER TABLE `system_public_logs` DISABLE KEYS */;
INSERT INTO `system_public_logs` (`id`, `created_at`, `user_id`, `item_unid`, `controller`, `action`) VALUES 
(1,'2011-05-21 22:17:51',1000,NULL,'System::Public::RolesController','destroy'),
(2,'2011-05-21 22:19:47',1000,NULL,'System::Public::RoleDevelopersController','destroy');
/*!40000 ALTER TABLE `system_public_logs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `system_publishers`
--


--
-- Dumping data for table `system_recognitions`
--


--
-- Dumping data for table `system_recognizers`
--


--
-- Dumping data for table `system_role_developers`
--


--
-- Dumping data for table `system_role_groups`
--


--
-- Dumping data for table `system_role_name_privs`
--

LOCK TABLES `system_role_name_privs` WRITE;
/*!40000 ALTER TABLE `system_role_name_privs` DISABLE KEYS */;
INSERT INTO `system_role_name_privs` (`id`, `role_id`, `priv_id`, `created_at`, `updated_at`) VALUES 
(17,4,1,'2010-11-02 10:10:00','2010-11-02 10:10:00'),
(33,6,1,'2010-11-02 10:10:00','2010-11-02 10:10:00'),
(153,21,1,'2010-11-02 10:10:00','2010-11-02 10:10:00'),
(161,37,8,'2010-11-02 10:10:00','2010-11-02 16:49:49'),
(192,41,1,'2010-11-06 16:47:30','2010-11-06 16:47:30'),
(203,39,10,'2011-02-07 18:55:34','2011-02-07 18:55:34'),
(207,52,1,'2014-03-04 11:19:28','2014-03-04 11:19:28'),
(208,53,1,'2014-03-05 09:35:20','2014-03-05 09:35:20'),
(209,54,1,'2014-03-20 16:47:39','2014-03-20 16:47:39');
/*!40000 ALTER TABLE `system_role_name_privs` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `system_role_names`
--

LOCK TABLES `system_role_names` WRITE;
/*!40000 ALTER TABLE `system_role_names` DISABLE KEYS */;
INSERT INTO `system_role_names` (`id`, `unid`, `state`, `content_id`, `created_at`, `updated_at`, `display_name`, `table_name`, `sort_no`) VALUES 
(4,NULL,NULL,NULL,'2010-07-29 10:30:45','2014-01-27 17:47:27','ファイル管理','doclibrary',130),
(6,NULL,NULL,NULL,'2010-07-29 10:31:12','2010-07-29 13:01:43','掲示板','gwbbs',110),
(21,NULL,NULL,NULL,'2010-07-29 10:34:55','2010-07-29 13:11:32','GW管理画面','_admin',1),
(37,NULL,NULL,NULL,'2010-08-04 10:00:31','2010-08-04 10:00:31','全庁予定登録','schedule_pref',11),
(39,NULL,NULL,NULL,'2010-10-04 20:36:11','2010-10-04 20:36:11','システムユーザー管理','system_users',910),
(41,NULL,NULL,NULL,'2010-11-19 10:46:14','2010-11-19 10:46:14','回覧板','gwcircular',105),
(52,NULL,NULL,NULL,'2014-03-04 11:18:02','2014-03-04 11:18:02','スケジューラー設定','schedule_role',120),
(53,NULL,NULL,NULL,'2014-03-05 09:34:50','2014-03-05 09:34:50','施設マスタ登録','schedule_prop_admin',125),
(54,NULL,NULL,NULL,'2014-03-20 16:44:28','2014-03-20 16:44:28','メール管理','mail_admin',100);
/*!40000 ALTER TABLE `system_role_names` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `system_roles`
--

LOCK TABLES `system_roles` WRITE;
/*!40000 ALTER TABLE `system_roles` DISABLE KEYS */;
INSERT INTO `system_roles` (`id`, `table_name`, `priv_name`, `idx`, `class_id`, `uid`, `priv`, `created_at`, `updated_at`, `role_name_id`, `priv_user_id`, `group_id`, `editable_groups_json`) VALUES 
(1,'_admin','admin',1,1,'1000',1,'2011-05-07 01:56:58','2011-05-07 21:41:30',21,1,100,NULL),
(3,'doclibrary','admin',1,1,'1000',1,'2011-05-11 18:41:01','2011-05-11 18:41:01',4,1,100,NULL),
(7,'gwbbs','admin',1,1,'1000',1,'2011-05-12 22:36:59','2011-05-12 22:36:59',6,1,100,NULL),
(13,'_admin','developer',1,1,'1000',1,'2011-05-21 22:24:07','2011-05-21 22:24:07',21,2,100,NULL),
(17,'gwcircular','admin',1,1,'1000',1,'2012-08-23 19:54:19','2012-08-23 19:54:19',41,1,100,NULL);
/*!40000 ALTER TABLE `system_roles` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `system_sequences`
--


--
-- Dumping data for table `system_tags`
--


--
-- Dumping data for table `system_tasks`
--


--
-- Dumping data for table `system_unids`
--


--
-- Dumping data for table `system_user_temporaries`
--


--
-- Dumping data for table `system_users`
--

LOCK TABLES `system_users` WRITE;
/*!40000 ALTER TABLE `system_users` DISABLE KEYS */;
INSERT INTO `system_users` (`id`, `air_login_id`, `state`, `created_at`, `updated_at`, `code`, `ldap`, `ldap_version`, `auth_no`, `name`, `name_en`, `kana`, `password`, `mobile_access`, `mobile_password`, `email`, `official_position`, `assigned_job`, `remember_token`, `remember_token_expires_at`, `air_token`, `sort_no`) VALUES 
(1000,NULL,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00','enisysadm',0,NULL,5,'システム管理者','','システムカンリシャ','enisysadm',NULL,NULL,'','','',NULL,NULL,NULL,999999),
(1001,NULL,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00','00100',0,NULL,2,'縁sys　太郎','','１１　１１','00100',NULL,NULL,'enisys-tarou@city.enisys.co.jp','','',NULL,NULL,NULL,100),
(1002,NULL,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00','00101',0,NULL,2,'副　次郎','','フク　ジロウ','00101',NULL,NULL,'jirou@city.enisys.co.jp','','',NULL,NULL,NULL,101),
(1003,NULL,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00','00200',0,NULL,2,'佐藤　一郎','','サトウ　イチロー','00200',NULL,NULL,'ichiro@city.enisys.co.jp','','',NULL,NULL,NULL,200),
(1004,NULL,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00','00201',0,NULL,2,'鈴木　敬','','スズキ　ケイ','00201',NULL,NULL,'suzuki-kei@city.enisys.co.jp','','',NULL,NULL,NULL,201),
(1005,NULL,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00','00202',0,NULL,2,'山田　大地','','ヤマダ　ダイチ','00202',NULL,NULL,'yamada-daichi@city.enisys.co.jp','','',NULL,NULL,NULL,202),
(1006,NULL,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00','00203',0,NULL,2,'錦織　花子','','ニシコリ　ハナコ','00203',NULL,NULL,'nishikori@city.enisys.co.jp','','',NULL,NULL,NULL,203),
(1007,NULL,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00','00204',0,NULL,2,'斉藤　晴美','','サイトウ　ハルミ','00204',NULL,NULL,'saitou-harumi@city.enisys.co.jp','','',NULL,NULL,NULL,204),
(1008,NULL,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00','00205',0,NULL,2,'縁　千春','','エニシ　チハル','00205',NULL,NULL,'enishi-chiharu@city.enisys.co.jp','','',NULL,NULL,NULL,205),
(1009,NULL,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00','00300',0,NULL,2,'鈴木　勇作','','スズキ　ユウサク','00300',NULL,NULL,'suzuki-yuusaku@city.enisys.co.jp','','',NULL,NULL,NULL,300),
(1010,NULL,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00','00301',0,NULL,2,'松田　志摩','','マツダ　シマ','00301',NULL,NULL,'matuda-shima@city.enisys.co.jp','','',NULL,NULL,NULL,301),
(2000,NULL,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00','enisysadmu1',0,NULL,2,'システム管理者用ユーザー１','','システムカンリシャヨウユーザー１','enisysadmu1',NULL,NULL,'','','',NULL,NULL,NULL,999001),
(2001,NULL,'enabled','2014-01-01 00:00:00','2014-01-01 00:00:00','enisysadmu2',0,NULL,2,'システム管理者用ユーザー２','','システムカンリシャヨウユーザー２','enisysadmu2',NULL,NULL,'','','',NULL,NULL,NULL,999002);
/*!40000 ALTER TABLE `system_users` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `system_users_custom_groups`
--

LOCK TABLES `system_users_custom_groups` WRITE;
/*!40000 ALTER TABLE `system_users_custom_groups` DISABLE KEYS */;
/*!40000 ALTER TABLE `system_users_custom_groups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `system_users_group_histories`
--


--
-- Dumping data for table `system_users_group_history_temporaries`
--


--
-- Dumping data for table `system_users_group_temporaries`
--


--
-- Dumping data for table `system_users_groups`
--

LOCK TABLES `system_users_groups` WRITE;
/*!40000 ALTER TABLE `system_users_groups` DISABLE KEYS */;
INSERT INTO `system_users_groups` (`rid`, `created_at`, `updated_at`, `user_id`, `group_id`, `job_order`, `start_at`, `end_at`, `user_code`, `group_code`) VALUES
(1,'2014-01-01 00:00:00','2014-01-01 00:00:00',1000,100,0,'2014-01-01 00:00:00',NULL,'enisysadm','SYSTEM'),
(2,'2014-01-01 00:00:00','2014-01-01 00:00:00',2000,100,0,'2014-01-01 00:00:00',NULL,'enisysadmu1','SYSTEM'),
(3,'2014-01-01 00:00:00','2014-01-01 00:00:00',2001,100,0,'2014-01-01 00:00:00',NULL,'enisysadmu2','SYSTEM'),
(4,'2014-01-01 00:00:00','2014-01-01 00:00:00',1001,111,0,'2014-01-01 00:00:00',NULL,'00100','999001'),
(5,'2014-01-01 00:00:00','2014-01-01 00:00:00',1002,111,0,'2014-01-01 00:00:00',NULL,'00101','999001'),
(6,'2014-01-01 00:00:00','2014-01-01 00:00:00',1003,121,0,'2014-01-01 00:00:00',NULL,'00200','010010'),
(7,'2014-01-01 00:00:00','2014-01-01 00:00:00',1004,121,0,'2014-01-01 00:00:00',NULL,'00201','010010'),
(8,'2014-01-01 00:00:00','2014-01-01 00:00:00',1005,122,0,'2014-01-01 00:00:00',NULL,'00202','010020'),
(9,'2014-01-01 00:00:00','2014-01-01 00:00:00',1006,122,0,'2014-01-01 00:00:00',NULL,'00203','010020'),
(10,'2014-01-01 00:00:00','2014-01-01 00:00:00',1007,123,0,'2014-01-01 00:00:00',NULL,'00204','010030'),
(11,'2014-01-01 00:00:00','2014-01-01 00:00:00',1008,123,0,'2014-01-01 00:00:00',NULL,'00205','010030'),
(12,'2014-01-01 00:00:00','2014-01-01 00:00:00',1009,131,0,'2014-01-01 00:00:00',NULL,'00300','500010'),
(13,'2014-01-01 00:00:00','2014-01-01 00:00:00',1010,131,0,'2014-01-01 00:00:00',NULL,'00301','500010');
/*!40000 ALTER TABLE `system_users_groups` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Dumping data for table `system_users_groups_csvdata`
--

--
-- Dumping data for table `system_users_profile_settings`
--


--
-- Dumping data for table `system_users_profiles`
--

/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;
/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2014-01-17  8:51:04
