-- +goose Up
-- +goose StatementBegin
ALTER TABLE client_queries 
ADD COLUMN pages_to_scrape INT DEFAULT 1; 
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE client_queries
DROP COLUMN pages_to_scrape;
-- +goose StatementEnd
