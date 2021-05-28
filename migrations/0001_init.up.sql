SET GLOBAL sql_mode =
        'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';
SET SESSION sql_mode =
        'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

CREATE TABLE IF NOT EXISTS session
(
    id         BIGINT PRIMARY KEY AUTO_INCREMENT,
    secret     CHAR(36) NOT NULL,
    uid        BIGINT   NOT NULL,
    expires_at BIGINT   NOT NULL
);

CREATE TABLE IF NOT EXISTS discord_user
(
    id            BIGINT PRIMARY KEY AUTO_INCREMENT,
    username      VARCHAR(255) NOT NULL,
    avatar        VARCHAR(255) NOT NULL,
    discriminator VARCHAR(255) NOT NULL,
    public_flags  BIGINT       NOT NULL,
    flags         BIGINT       NOT NULL,
    locale        VARCHAR(255) NOT NULL,
    mfa_enabled   BIGINT       NOT NULL
);

INSERT IGNORE INTO discord_user (id, username, avatar, discriminator, public_flags, flags, locale, mfa_enabled)
VALUES (810112564787675166, 'RedMinima', '156dd40e0c72ed8e84034b53aad32af4', '1337', 0, 0, 'en_US', 0);

CREATE TABLE IF NOT EXISTS authorization
(
    id         BIGINT PRIMARY KEY AUTO_INCREMENT,
    fk_uid     BIGINT NOT NULL,
    authorized BIGINT NOT NULL,
    CONSTRAINT authorization_fk_uid FOREIGN KEY (fk_uid) REFERENCES discord_user (id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS submission
(
    id BIGINT PRIMARY KEY AUTO_INCREMENT
);

CREATE TABLE IF NOT EXISTS submission_file
(
    id                BIGINT PRIMARY KEY AUTO_INCREMENT,
    fk_uploader_id    BIGINT              NOT NULL,
    fk_submission_id  BIGINT              NOT NULL,
    original_filename VARCHAR(1023)       NOT NULL,
    current_filename  VARCHAR(255) UNIQUE NOT NULL,
    size              BIGINT              NOT NULL,
    uploaded_at       BIGINT              NOT NULL,
    md5sum            CHAR(32) UNIQUE     NOT NULL,
    sha256sum         CHAR(64) UNIQUE     NOT NULL,
    FOREIGN KEY (fk_uploader_id) REFERENCES discord_user (id),
    FOREIGN KEY (fk_submission_id) REFERENCES submission (id)
);
CREATE INDEX idx_submission_file_uploaded_at ON submission_file (uploaded_at);

CREATE TABLE IF NOT EXISTS curation_meta
(
    id                    BIGINT PRIMARY KEY AUTO_INCREMENT,
    fk_submission_file_id BIGINT NOT NULL,
    application_path      TEXT,
    developer             TEXT,
    extreme               TEXT,
    game_notes            TEXT,
    languages             TEXT,
    launch_command        TEXT,
    original_description  TEXT,
    play_mode             TEXT,
    platform              TEXT,
    publisher             TEXT,
    release_date          TEXT,
    series                TEXT,
    source                TEXT,
    status                TEXT,
    tags                  TEXT,
    tag_categories        TEXT,
    title                 TEXT,
    alternate_titles      TEXT,
    library               TEXT,
    version               TEXT,
    curation_notes        TEXT,
    mount_parameters      TEXT,
    FOREIGN KEY (fk_submission_file_id) REFERENCES submission_file (id)
);

CREATE TABLE IF NOT EXISTS action
(
    id   BIGINT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(63) UNIQUE
);

INSERT IGNORE INTO action (id, name)
VALUES (1, 'comment'),
       (2, 'approve'),
       (3, 'request-changes'),
       (4, 'accept'),
       (5, 'mark-added'),
       (6, 'reject'),
       (7, 'upload-file');

CREATE TABLE IF NOT EXISTS comment
(
    id               BIGINT PRIMARY KEY AUTO_INCREMENT,
    fk_author_id     BIGINT NOT NULL,
    fk_submission_id BIGINT NOT NULL,
    message          TEXT,
    fk_action_id     BIGINT,
    created_at       BIGINT NOT NULL,
    FOREIGN KEY (fk_author_id) REFERENCES discord_user (id),
    FOREIGN KEY (fk_submission_id) REFERENCES submission (id),
    FOREIGN KEY (fk_action_id) REFERENCES action (id)
);
CREATE INDEX idx_comment_created_at ON comment (created_at);