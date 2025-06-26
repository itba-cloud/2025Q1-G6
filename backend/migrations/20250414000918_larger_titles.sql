-- +goose Up
-- +goose StatementBegin
ALTER TABLE products
ALTER COLUMN name TYPE VARCHAR(255);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE products
ALTER COLUMN name TYPE VARCHAR(100);
-- +goose StatementEnd
