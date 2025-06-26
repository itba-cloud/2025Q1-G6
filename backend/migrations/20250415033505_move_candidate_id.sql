-- +goose Up
-- +goose StatementBegin
ALTER TABLE product_candidates
ADD COLUMN listing_id TEXT;

-- Take all rows from product_candidates and set the listing_id to the id of the listing
UPDATE product_candidates
SET listing_id = listings.id
FROM listings
WHERE product_candidates.id = listings.candidate_id;

-- Remove the candidate_id column from listings

ALTER TABLE listings
ALTER COLUMN id SET DATA TYPE TEXT USING id::TEXT;
ALTER TABLE listings
DROP COLUMN candidate_id;

ALTER TABLE product_candidates
ALTER COLUMN listing_id SET NOT NULL;

ALTER TABLE product_candidates
ADD CONSTRAINT fk_listing_id FOREIGN KEY (listing_id) REFERENCES listings(id) ON DELETE CASCADE;
-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
ALTER TABLE listings
ADD COLUMN candidate_id INT;

ALTER TABLE listings
ADD CONSTRAINT fk_listing_id FOREIGN KEY (candidate_id) REFERENCES product_candidates(id) ON DELETE CASCADE;

UPDATE listings
SET candidate_id = product_candidates.id
FROM product_candidates
WHERE listings.id = product_candidates.listing_id;

ALTER TABLE product_candidates
DROP CONSTRAINT fk_listing_id,
DROP COLUMN listing_id;


ALTER TABLE listings
ALTER COLUMN candidate_id SET NOT NULL;
-- +goose StatementEnd
