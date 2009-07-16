DROP TABLE IF EXISTS `MAPPING`;

CREATE TABLE `MAPPING` (
  `contig_id` mediumint(8) unsigned NOT NULL default '0',
  `read_id` mediumint(8) unsigned NOT NULL default '0',
  `mapping_id` mediumint(8) unsigned NOT NULL auto_increment,
  `revision` mediumint(8) unsigned NOT NULL default '0',
  INDEX (`contig_id`),
  INDEX (`read_id`),
  PRIMARY KEY `mapping_id` (`mapping_id`)
);

DROP TABLE IF EXISTS `SEGMENT`;

CREATE TABLE `SEGMENT` (
  `mapping_id` mediumint(8) unsigned NOT NULL default '0',
  `pcstart` int(10) unsigned NOT NULL default '0',
  `pcfinal` int(10) unsigned NOT NULL default '0',
  `prstart` smallint(5) unsigned NOT NULL default '0',
  `prfinal` smallint(5) unsigned NOT NULL default '0',
  `label` tinyint(3) unsigned NOT NULL default '0',
  INDEX (`mapping_id`)
);
