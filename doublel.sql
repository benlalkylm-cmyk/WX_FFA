CREATE TABLE IF NOT EXISTS `ffa` (
  `identifier` char(50) NOT NULL,
  `kills` int(11) DEFAULT 0,
  `deaths` int(11) DEFAULT 0,
  `name` varchar(100) DEFAULT NULL,
  `discord` varchar(50) DEFAULT NULL,
  `lastplayed` int(11) DEFAULT 0,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

CREATE TABLE IF NOT EXISTS `data_ffa` (
  `identifier` char(50) NOT NULL,
  `zoneID` varchar(100) NOT NULL,
  PRIMARY KEY (`identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- ----------------------------------------------------------
--  If you already have an older `ffa` table, run these once:
-- ----------------------------------------------------------
-- ALTER TABLE `ffa` ADD COLUMN `name` varchar(100) DEFAULT NULL;
-- ALTER TABLE `ffa` ADD COLUMN `discord` varchar(50) DEFAULT NULL;
-- ALTER TABLE `ffa` ADD COLUMN `lastplayed` int(11) DEFAULT 0;
