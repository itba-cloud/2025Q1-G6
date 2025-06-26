-- +goose Up
-- +goose StatementBegin

CREATE EXTENSION IF NOT EXISTS vector;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Clients table: stores client info.
CREATE TABLE clients (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Queries table: stores the text of queries.
CREATE TABLE queries (
    id SERIAL PRIMARY KEY,
    query_text TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    removed_at TIMESTAMP DEFAULT NULL
);

-- Define an ENUM type for query frequency.
CREATE TYPE query_frequency AS ENUM (
    'hourly',
    'daily',
    'weekly',
    'monthly'
);

-- Client_queries: associates clients with queries.
CREATE TABLE client_queries (
    id SERIAL PRIMARY KEY,
    client_id INT NOT NULL,
    query_id INT NOT NULL,
    frequency query_frequency NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    removed_at TIMESTAMP DEFAULT NULL,
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE,
    FOREIGN KEY (query_id) REFERENCES queries(id) ON DELETE CASCADE
);

-- Products: stores product information.
CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    manual_override BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Product_embeddings: stores vector representations (e.g., for similarity search).
CREATE TABLE product_embeddings (
    id SERIAL PRIMARY KEY,
    product_id INT UNIQUE REFERENCES products(id) ON DELETE CASCADE,
    embedding VECTOR(384) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Marketplaces: stores marketplace information.
CREATE TABLE marketplaces (
    id SERIAL PRIMARY KEY,
    name TEXT,
    region TEXT,
    domain TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Product_candidates: maps a product against a query using a specific matching method.
CREATE TABLE product_candidates (
    id SERIAL PRIMARY KEY,
    query_id INT NOT NULL REFERENCES queries(id) ON DELETE CASCADE,
    product_id INT NOT NULL REFERENCES products(id) ON DELETE CASCADE,
    match_method TEXT NOT NULL,  -- 'vector', 'levenshtein', 'manual'
    distance FLOAT,
    decided BOOLEAN DEFAULT FALSE,
    decided_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP

);

-- Listings: each listing is tied to a candidate match.
-- Renamed the foreign key reference column to candidate_id for clarity.
CREATE TABLE listings (
    id TEXT PRIMARY KEY DEFAULT gen_random_uuid(),
    marketplace_id INT REFERENCES marketplaces(id) ON DELETE SET NULL,
    candidate_id INT UNIQUE NOT NULL REFERENCES product_candidates(id) ON DELETE CASCADE,
    external_id TEXT,
    title TEXT,
    url TEXT,
    seller TEXT,
    condition TEXT,
    availability TEXT,
    last_seen TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT unique_marketplace_external UNIQUE (marketplace_id, external_id)
);

-- Prices: store pricing information for each listing.
CREATE TABLE prices (
    id SERIAL PRIMARY KEY,
    listing_id TEXT REFERENCES listings(id) ON DELETE CASCADE,
    price NUMERIC,
    currency TEXT,
    scraped_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Add a trigram index on product names for fast fuzzy searching.
CREATE INDEX idx_products_name_trgm ON products USING gin (name gin_trgm_ops);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP TABLE IF EXISTS prices;
DROP TABLE IF EXISTS listings;
DROP TABLE IF EXISTS product_candidates;
DROP TABLE IF EXISTS product_embeddings;
DROP TABLE IF EXISTS marketplaces;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS client_queries;
DROP TABLE IF EXISTS queries;
DROP TABLE IF EXISTS clients;
DROP TYPE IF EXISTS query_frequency;
DROP EXTENSION IF EXISTS pg_trgm;
DROP EXTENSION IF EXISTS vector;
-- +goose StatementEnd
