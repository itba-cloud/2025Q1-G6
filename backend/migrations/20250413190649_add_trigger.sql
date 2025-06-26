-- +goose Up
-- +goose StatementBegin
CREATE OR REPLACE FUNCTION update_listings_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE listings
    SET last_seen = NOW()
    WHERE listings.id = NEW.listing_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_listings_updated_at
AFTER INSERT ON prices
FOR EACH ROW
EXECUTE FUNCTION update_listings_updated_at();
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TRIGGER IF EXISTS trigger_update_listings_updated_at ON prices;
DROP FUNCTION IF EXISTS update_listings_updated_at();
-- +goose StatementEnd
