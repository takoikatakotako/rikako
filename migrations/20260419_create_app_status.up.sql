CREATE TABLE app_status (
    id              BOOLEAN PRIMARY KEY DEFAULT TRUE,
    is_maintenance  BOOLEAN NOT NULL DEFAULT FALSE,
    maintenance_message TEXT NOT NULL DEFAULT '',
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    CONSTRAINT single_row CHECK (id = TRUE)
);

INSERT INTO app_status (id, is_maintenance, maintenance_message)
VALUES (TRUE, FALSE, '');
