-- =============================================
--  gc-section8 | Decoration Table
--  Run AFTER gc_section8.sql
-- =============================================

CREATE TABLE IF NOT EXISTS `gc_section8_decor` (
    `id`         int(11)      NOT NULL AUTO_INCREMENT,
    `citizenid`  varchar(50)  NOT NULL,
    `unit_id`    varchar(50)  NOT NULL,
    `prop_model` varchar(100) NOT NULL,
    `pos_x`      float        NOT NULL DEFAULT 0,
    `pos_y`      float        NOT NULL DEFAULT 0,
    `pos_z`      float        NOT NULL DEFAULT 0,
    `rot_z`      float        NOT NULL DEFAULT 0,
    `placed_at`  timestamp    NOT NULL DEFAULT current_timestamp(),
    PRIMARY KEY (`id`),
    KEY `citizenid` (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
