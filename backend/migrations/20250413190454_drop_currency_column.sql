-- +goose Up
-- +goose StatementBegin
ALTER TABLE prices
DROP COLUMN currency;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE prices
ADD COLUMN currency TEXT;
-- +goose StatementEnd
