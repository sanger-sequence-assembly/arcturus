DROP TABLE IF EXISTS `PROJECT_CONTIG_HISTORY`;
CREATE TABLE IF NOT EXISTS `PROJECT_CONTIG_HISTORY` (
  `project_id` mediumint(8) unsigned NOT NULL default '0',
	`statsdate` date not null , 
	`name` varchar(40) not null,
	`total_contigs` int(12) unsigned NOT NULL default 0,
	`total_reads` int(18) unsigned NOT NULL default 0,
	`total_contig_length` int(12) unsigned NOT NULL default 0,
	`mean_contig_length` int(12) unsigned NOT NULL default 0,
	`stddev_contig_length` int(12) unsigned NOT NULL default 0,
	`max_contig_length` int(12) unsigned NOT NULL default 0,
	`n50_contig_length` int(12) unsigned NOT NULL default 0,
  PRIMARY KEY (`project_id`,`statsdate`),
  KEY `statsdate` (`statsdate`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
