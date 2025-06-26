-- +goose Up
-- +goose StatementBegin
INSERT INTO marketplaces (id, name, domain, region)
VALUES (1, 'Mercado Libre', 'https://www.mercadolibre.com.ar', 'Argentina');
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DELETE FROM marketplaces
WHERE id = 1;
-- +goose StatementEnd
