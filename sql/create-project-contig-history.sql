DROP TABLE `PROJECT_CONTIG_HISTORY`;
CREATE TABLE `PROJECT_CONTIG_HISTORY` (
  `project_id` mediumint(8) unsigned NOT NULL default '0',
	`statsdate` date not null , 
	`total_contigs` int(12) unsigned NOT NULL default 0,
	`total_reads` int(12) unsigned NOT NULL default 0,
	`total_contig_length` int(12) unsigned NOT NULL default 0,
	`mean_contig_length` int(12) unsigned NOT NULL default 0,
	`stddev_contig_length` int(12) unsigned NOT NULL default 0,
	`max_contig_length` int(12) unsigned NOT NULL default 0,
	`median_contig_length` int(12) unsigned NOT NULL default 0,
  PRIMARY KEY (`project_id`,`statsdate`),
  KEY `project_id` (`project_id`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
