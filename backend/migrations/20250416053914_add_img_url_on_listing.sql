-- +goose Up
-- +goose StatementBegin
ALTER TABLE listings
ADD COLUMN img_url VARCHAR(255) DEFAULT NULL;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE listings
DROP COLUMN img_url;
-- +goose StatementEnd
