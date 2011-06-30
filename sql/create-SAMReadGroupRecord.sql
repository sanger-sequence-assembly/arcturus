DROP TABLE IF EXISTS `SAMREADGROUPRECORD`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `SAMREADGROUPRECORD` (
   `read_group_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
   `read_group_line_id` int(10) NOT NULL,
	 `import_id` int(10) unsigned NOT NULL, 
   `IDvalue` char(100) NOT NULL,
	 `SMvalue` char(100) NOT NULL,
	 `LBvalue` char(100) NULL,
	 `DSvalue` char(100) NULL,
	 `PUvalue` char(100) NULL,
	 `PIvalue` char(100) NULL,
	 `CNvalue` char(100) NULL,
	 `DTvalue` char(100) NULL,
	 `PLvalue` char(100) NULL,
   PRIMARY KEY (`read_group_id`),
   KEY `read_group_id` (`read_group_id`),
	 CONSTRAINT `SAMREADGROUPRECORD_ibfk_1` FOREIGN KEY (`import_id`) REFERENCES `IMPORTEXPORT` (`id`) ON DELETE CASCADE
 ) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

