-- =============================================
--  gc-section8 | Database Setup
--  Run this before starting the resource.
--  Safe to run on existing installs (uses IF NOT EXISTS / IF NOT EXISTS column).
-- =============================================

CREATE TABLE IF NOT EXISTS `gc_section8_units` (
    `id`                varchar(50)  NOT NULL,
    `label`             varchar(100) NOT NULL,
    `size`              varchar(20)  NOT NULL DEFAULT 'studio',
    `max_occupants`     int(11)      NOT NULL DEFAULT 2,
    `door_id`           int(11)               DEFAULT NULL,
    `coords_x`          float        NOT NULL DEFAULT 0,
    `coords_y`          float        NOT NULL DEFAULT 0,
    `coords_z`          float        NOT NULL DEFAULT 0,
    `rent_base`         int(11)      NOT NULL DEFAULT 250,
    `tenant_citizenid`  varchar(50)           DEFAULT NULL,
    `tenant_name`       varchar(100)          DEFAULT NULL,
    `occupied`          tinyint(1)   NOT NULL DEFAULT 0,
    `created_at`        timestamp    NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gc_section8_applications` (
    `id`              int(11)      NOT NULL AUTO_INCREMENT,
    `citizenid`       varchar(50)  NOT NULL,
    `player_name`     varchar(100) NOT NULL,
    `job_type`        varchar(100) NOT NULL,
    `monthly_income`  int(11)      NOT NULL,
    `has_kids`        tinyint(1)   NOT NULL DEFAULT 0,
    `num_kids`        int(11)      NOT NULL DEFAULT 0,
    `sex`             varchar(10)  NOT NULL DEFAULT 'male',
    `extra_occupants` varchar(255)          DEFAULT NULL,
    `status`          enum('pending','approved','denied') NOT NULL DEFAULT 'pending',
    `assigned_unit`   varchar(50)           DEFAULT NULL,
    `rent_amount`     int(11)               DEFAULT NULL,
    `approved_by`     varchar(100)          DEFAULT NULL,
    `submitted_at`    timestamp    NOT NULL DEFAULT current_timestamp(),
    `reviewed_at`     DATETIME             DEFAULT NULL,
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gc_section8_rent` (
    `id`          int(11)     NOT NULL AUTO_INCREMENT,
    `citizenid`   varchar(50) NOT NULL,
    `unit_id`     varchar(50) NOT NULL,
    `rent_amount` int(11)     NOT NULL,
    `last_paid`   timestamp   NOT NULL DEFAULT current_timestamp(),
    `due_date`    timestamp   NOT NULL,
    `warned`      tinyint(1)  NOT NULL DEFAULT 0,
    `warn_date`   DATETIME             DEFAULT NULL,
    PRIMARY KEY (`id`),
    UNIQUE KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gc_section8_settings` (
    `key`   varchar(50)  NOT NULL,
    `value` varchar(255) NOT NULL,
    PRIMARY KEY (`key`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO `gc_section8_settings` (`key`, `value`) VALUES ('npc_mode', '1');

CREATE TABLE IF NOT EXISTS `gc_section8_snap` (
    `id`             int(11)     NOT NULL AUTO_INCREMENT,
    `citizenid`      varchar(50) NOT NULL,
    `monthly_amount` int(11)     NOT NULL DEFAULT 210,
    `balance`        int(11)     NOT NULL DEFAULT 0,
    `next_reload`    timestamp   NOT NULL,
    `pin_hash`       varchar(50)          DEFAULT NULL,
    `pin_attempts`   int(11)     NOT NULL DEFAULT 0,
    `replacement_at` DATETIME             DEFAULT NULL,
    `created_at`     timestamp   NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (`id`),
    UNIQUE KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `gc_section8_decor` (
    `id`          int(11)     NOT NULL AUTO_INCREMENT,
    `citizenid`   varchar(50) NOT NULL,
    `unit_id`     varchar(50) NOT NULL,
    `prop_model`  varchar(100) NOT NULL,
    `pos_x`       float        NOT NULL DEFAULT 0,
    `pos_y`       float        NOT NULL DEFAULT 0,
    `pos_z`       float        NOT NULL DEFAULT 0,
    `rot_z`       float        NOT NULL DEFAULT 0,
    `placed_at`   timestamp    NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =============================================
--  MIGRATION: upgrading from a previous install?
--  Run these if your old tables already exist.
-- =============================================

-- ALTER TABLE `gc_section8_snap`
--     ADD COLUMN IF NOT EXISTS `pin_hash`       varchar(50)  DEFAULT NULL,
--     ADD COLUMN IF NOT EXISTS `pin_attempts`   int(11)      NOT NULL DEFAULT 0,
--     ADD COLUMN IF NOT EXISTS `replacement_at` DATETIME DEFAULT NULL;
