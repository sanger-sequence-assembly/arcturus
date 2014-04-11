--
-- Table structure for table `JMXURL`
--

CREATE TABLE `JMXURL` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `created` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `user` char(8) NOT NULL,
  `url` varchar(500) NOT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `LOGRECORD`
--

CREATE TABLE `LOGRECORD` (
  `id` int(11) NOT NULL AUTO_INCREMENT,
  `parent` int(11) NOT NULL DEFAULT '0',
  `time` bigint(20) NOT NULL,
  `sequence` bigint(20) NOT NULL,
  `logger` text,
  `level` int(11) NOT NULL,
  `class` text,
  `method` text,
  `thread` int(11) NOT NULL,
  `message` text,
  `user` text,
  `host` text,
  `connid` int(11) NOT NULL,
  `revision` text,
  `errorcode` int(11) DEFAULT NULL,
  `errorstate` text,
  `exceptionclass` text,
  `exceptionmessage` text,
  PRIMARY KEY (`id`),
  KEY `parent` (`parent`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `PRIVILEGE`
--

CREATE TABLE `PRIVILEGE` (
  `privilege` char(32) NOT NULL,
  `description` char(200) NOT NULL,
  PRIMARY KEY (`privilege`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `SESSION`
--

CREATE TABLE `SESSION` (
  `username` char(8) NOT NULL DEFAULT '',
  `default_role` char(32) DEFAULT NULL,
  `api_key` char(32) DEFAULT NULL,
  `api_key_expires` datetime DEFAULT NULL,
  `auth_key` char(32) DEFAULT NULL,
  `auth_key_expires` datetime DEFAULT NULL,
  PRIMARY KEY (`username`),
  UNIQUE KEY `api_key` (`api_key`),
  UNIQUE KEY `auth_key` (`auth_key`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;

--
-- Table structure for table `STACKTRACE`
--

CREATE TABLE `STACKTRACE` (
  `id` int(11) NOT NULL,
  `sequence` bigint(20) NOT NULL,
  `class` text,
  `method` text,
  `line` int(11) NOT NULL,
  KEY `id` (`id`),
  CONSTRAINT `STACKTRACE_ibfk_1` FOREIGN KEY (`id`) REFERENCES `LOGRECORD` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

--
-- Table structure for table `USER`
--

CREATE TABLE `USER` (
  `username` char(8) NOT NULL,
  `role` char(32) NOT NULL DEFAULT 'finisher',
  PRIMARY KEY (`username`)
) ENGINE=MyISAM DEFAULT CHARSET=latin1;
