DROP TABLE IF EXISTS `READGROUP`;
SET @saved_cs_client     = @@character_set_client;
SET character_set_client = utf8;
CREATE TABLE `READGROUP` (
   `read_group_id` int(10) unsigned NOT NULL AUTO_INCREMENT,
   `read_group_line_id` int(10) NOT NULL,
	 `import_id` int(10) unsigned NOT NULL, 
   `tag_name` enum('ID', 'SM', 'LB', 'DS', 'PU', 'PI', 'CN', 'DT', 'PL') NOT NULL,
   `tag_value` char(100) NOT NULL,
   PRIMARY KEY (`read_group_id`),
   KEY `read_group_id` (`read_group_id`),
	 CONSTRAINT `READGROUP_ibfk_1` FOREIGN KEY (`import_id`) REFERENCES `IMPORTEXPORT` (`id`) ON DELETE CASCADE
 ) ENGINE=InnoDB DEFAULT CHARSET=latin1;
SET character_set_client = @saved_cs_client;

