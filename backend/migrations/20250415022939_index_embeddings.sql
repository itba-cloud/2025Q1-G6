-- +goose Up
-- +goose StatementBegin
CREATE INDEX ON product_embeddings
USING hnsw (embedding vector_cosine_ops)
WITH (
    m = 16,          -- Number of bi-directional links (higher = more accurate, slower to build)
    ef_construction = 64  -- Trade-off between speed and accuracy during indexing
);

-- +goose StatementEnd

-- +goose Down
-- +goose StatementBegin
DROP INDEX IF EXISTS product_embeddings_idx;
-- +goose StatementEnd
