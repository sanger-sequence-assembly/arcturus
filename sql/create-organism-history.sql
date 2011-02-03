DROP TABLE IF EXISTS `ORGANISM_HISTORY`;
CREATE TABLE IF NOT EXISTS `ORGANISM_HISTORY` (
  `organism` varchar(40) not null,
	`statsdate` date not null , 
	`total_reads` int(12) unsigned NOT NULL default 0,
	`reads_in_contigs` int(12) unsigned NOT NULL default 0,
	`free_reads` int(12) unsigned NOT NULL default 0,
	`asped_reads` int(12) unsigned NOT NULL default 0,
	`next_gen_reads` int(12) unsigned NOT NULL default 0,
  PRIMARY KEY (`organism`,`statsdate`),
  KEY `statsdate` (`statsdate`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
