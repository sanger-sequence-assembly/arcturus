CREATE TABLE `HISTORY` (`tablename` varchar(20) not null,
			`date` datetime not null,
			`user` varchar(20) not null,
			`action` varchar(20) not null,
			`command` text not null
			) TYPE=MyISAM
