from typing import Any, List, Optional

from pgvector.sqlalchemy.vector import VECTOR
from sqlalchemy import BigInteger, Boolean, DateTime, Double, Enum, ForeignKeyConstraint, Identity, Index, Integer, Numeric, PrimaryKeyConstraint, String, Text, UniqueConstraint, text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column, relationship
import datetime
import decimal

class Base(DeclarativeBase):
    pass


class Clients(Base):
    __tablename__ = 'clients'
    __table_args__ = (
        PrimaryKeyConstraint('id', name='clients_pkey'),
        UniqueConstraint('email', name='clients_email_key')
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(100))
    email: Mapped[str] = mapped_column(String(100))
    created_at: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime, server_default=text('CURRENT_TIMESTAMP'))

    client_queries: Mapped[List['ClientQueries']] = relationship('ClientQueries', back_populates='client')


class GooseDbVersion(Base):
    __tablename__ = 'goose_db_version'
    __table_args__ = (
        PrimaryKeyConstraint('id', name='goose_db_version_pkey'),
    )

    id: Mapped[int] = mapped_column(Integer, Identity(start=1, increment=1, minvalue=1, maxvalue=2147483647, cycle=False, cache=1), primary_key=True)
    version_id: Mapped[int] = mapped_column(BigInteger)
    is_applied: Mapped[bool] = mapped_column(Boolean)
    tstamp: Mapped[datetime.datetime] = mapped_column(DateTime, server_default=text('now()'))


class Marketplaces(Base):
    __tablename__ = 'marketplaces'
    __table_args__ = (
        PrimaryKeyConstraint('id', name='marketplaces_pkey'),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[Optional[str]] = mapped_column(Text)
    region: Mapped[Optional[str]] = mapped_column(Text)
    domain: Mapped[Optional[str]] = mapped_column(Text)
    created_at: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime, server_default=text('CURRENT_TIMESTAMP'))

    listings: Mapped[List['Listings']] = relationship('Listings', back_populates='marketplace')


class Products(Base):
    __tablename__ = 'products'
    __table_args__ = (
        PrimaryKeyConstraint('id', name='products_pkey'),
        Index('idx_products_name_trgm', 'name')
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    name: Mapped[str] = mapped_column(String(255))
    manual_override: Mapped[Optional[bool]] = mapped_column(Boolean, server_default=text('false'))
    created_at: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime, server_default=text('CURRENT_TIMESTAMP'))

    product_embeddings: Mapped[Optional['ProductEmbeddings']] = relationship('ProductEmbeddings', uselist=False, back_populates='product')
    product_candidates: Mapped[List['ProductCandidates']] = relationship('ProductCandidates', back_populates='product')


class Queries(Base):
    __tablename__ = 'queries'
    __table_args__ = (
        PrimaryKeyConstraint('id', name='queries_pkey'),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    query_text: Mapped[str] = mapped_column(Text)
    created_at: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime, server_default=text('CURRENT_TIMESTAMP'))
    removed_at: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime)

    client_queries: Mapped[List['ClientQueries']] = relationship('ClientQueries', back_populates='query')
    product_candidates: Mapped[List['ProductCandidates']] = relationship('ProductCandidates', back_populates='query')


class ClientQueries(Base):
    __tablename__ = 'client_queries'
    __table_args__ = (
        ForeignKeyConstraint(['client_id'], ['clients.id'], ondelete='CASCADE', name='client_queries_client_id_fkey'),
        ForeignKeyConstraint(['query_id'], ['queries.id'], ondelete='CASCADE', name='client_queries_query_id_fkey'),
        PrimaryKeyConstraint('id', name='client_queries_pkey')
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    client_id: Mapped[int] = mapped_column(Integer)
    query_id: Mapped[int] = mapped_column(Integer)
    frequency: Mapped[str] = mapped_column(Enum('hourly', 'daily', 'weekly', 'monthly', name='query_frequency'))
    created_at: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime, server_default=text('CURRENT_TIMESTAMP'))
    removed_at: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime)
    pages_to_scrape: Mapped[Optional[int]] = mapped_column(Integer, server_default=text('1'))

    client: Mapped['Clients'] = relationship('Clients', back_populates='client_queries')
    query: Mapped['Queries'] = relationship('Queries', back_populates='client_queries')


class Listings(Base):
    __tablename__ = 'listings'
    __table_args__ = (
        ForeignKeyConstraint(['marketplace_id'], ['marketplaces.id'], ondelete='SET NULL', name='listings_marketplace_id_fkey'),
        PrimaryKeyConstraint('id', name='listings_pkey'),
        UniqueConstraint('marketplace_id', 'external_id', name='unique_marketplace_external')
    )

    id: Mapped[str] = mapped_column(Text, primary_key=True, server_default=text('gen_random_uuid()'))
    marketplace_id: Mapped[Optional[int]] = mapped_column(Integer)
    external_id: Mapped[Optional[str]] = mapped_column(Text)
    title: Mapped[Optional[str]] = mapped_column(Text)
    url: Mapped[Optional[str]] = mapped_column(Text)
    seller: Mapped[Optional[str]] = mapped_column(Text)
    condition: Mapped[Optional[str]] = mapped_column(Text)
    availability: Mapped[Optional[str]] = mapped_column(Text)
    last_seen: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime)
    created_at: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime, server_default=text('CURRENT_TIMESTAMP'))
    img_url: Mapped[Optional[str]] = mapped_column(String(255), server_default=text('NULL::character varying'))

    marketplace: Mapped[Optional['Marketplaces']] = relationship('Marketplaces', back_populates='listings')
    prices: Mapped[List['Prices']] = relationship('Prices', back_populates='listing')
    product_candidates: Mapped[List['ProductCandidates']] = relationship('ProductCandidates', back_populates='listing')


class ProductEmbeddings(Base):
    __tablename__ = 'product_embeddings'
    __table_args__ = (
        ForeignKeyConstraint(['product_id'], ['products.id'], ondelete='CASCADE', name='product_embeddings_product_id_fkey'),
        PrimaryKeyConstraint('id', name='product_embeddings_pkey'),
        UniqueConstraint('product_id', name='product_embeddings_product_id_key'),
        Index('product_embeddings_embedding_idx', 'embedding'),
        Index('product_embeddings_embedding_idx1', 'embedding')
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    embedding: Mapped[Any] = mapped_column(VECTOR(384))
    product_id: Mapped[Optional[int]] = mapped_column(Integer)
    created_at: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime, server_default=text('CURRENT_TIMESTAMP'))

    product: Mapped[Optional['Products']] = relationship('Products', back_populates='product_embeddings')


class Prices(Base):
    __tablename__ = 'prices'
    __table_args__ = (
        ForeignKeyConstraint(['listing_id'], ['listings.id'], ondelete='CASCADE', name='prices_listing_id_fkey'),
        PrimaryKeyConstraint('id', name='prices_pkey')
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    listing_id: Mapped[Optional[str]] = mapped_column(Text)
    price: Mapped[Optional[decimal.Decimal]] = mapped_column(Numeric)
    scraped_at: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime, server_default=text('CURRENT_TIMESTAMP'))

    listing: Mapped[Optional['Listings']] = relationship('Listings', back_populates='prices')


class ProductCandidates(Base):
    __tablename__ = 'product_candidates'
    __table_args__ = (
        ForeignKeyConstraint(['listing_id'], ['listings.id'], ondelete='CASCADE', name='fk_listing_id'),
        ForeignKeyConstraint(['product_id'], ['products.id'], ondelete='CASCADE', name='product_candidates_product_id_fkey'),
        ForeignKeyConstraint(['query_id'], ['queries.id'], ondelete='CASCADE', name='product_candidates_query_id_fkey'),
        PrimaryKeyConstraint('id', name='product_candidates_pkey')
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    query_id: Mapped[int] = mapped_column(Integer)
    product_id: Mapped[int] = mapped_column(Integer)
    match_method: Mapped[str] = mapped_column(Text)
    listing_id: Mapped[str] = mapped_column(Text)
    distance: Mapped[Optional[float]] = mapped_column(Double(53))
    decided: Mapped[Optional[bool]] = mapped_column(Boolean, server_default=text('false'))
    decided_at: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime)
    created_at: Mapped[Optional[datetime.datetime]] = mapped_column(DateTime, server_default=text('CURRENT_TIMESTAMP'))

    listing: Mapped['Listings'] = relationship('Listings', back_populates='product_candidates')
    product: Mapped['Products'] = relationship('Products', back_populates='product_candidates')
    query: Mapped['Queries'] = relationship('Queries', back_populates='product_candidates')
