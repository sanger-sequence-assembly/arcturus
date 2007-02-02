CREATE TABLE `HASHING` (
  `contig_id` mediumint(8) unsigned NOT NULL default '0',
  `offset` int(10) unsigned NOT NULL default '0',
  `hash` int(10) unsigned NOT NULL default '0',
  `hashsize` tinyint(3) unsigned NOT NULL default '0',
  UNIQUE KEY `contig_id` (`contig_id`,`offset`),
  KEY `hash` (`hash`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
