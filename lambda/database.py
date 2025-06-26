from models import *
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.exc import PendingRollbackError
import os

import logging
import traceback
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("scraper-DB")
class Database:
    def __init__(self):
        DATABASE_URL = os.getenv("DATABASE_URL", "postgresql+psycopg2://postgres:secret@db:5432/postgres")
        if DATABASE_URL.startswith("postgres://"):
            DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql+psycopg2://")
        logger.info(f"Using DATABASE_URL: {DATABASE_URL}")
        
        try:
            self.engine = create_engine(DATABASE_URL, pool_pre_ping=True)
            self.session = sessionmaker(bind=self.engine)()
            
            # Test the connection
            self.session.execute(text("SELECT 1"))
            logger.info("✅ Database connection successful")
            
            # Initialize database tables
            self.initialize_database()
            
        except Exception as e:
            logger.error(f"❌ Database connection failed: {e}")
            # Initialize session anyway for health checks
            self.engine = create_engine(DATABASE_URL, pool_pre_ping=True)
            self.session = sessionmaker(bind=self.engine)()
    def initialize_database(self):
        """
        Initialize database tables and basic data
        """
        try:
            try:
                self.session.rollback()
            except Exception as e:
                logger.error(f"Error during rollback: {e}")
            # Enable pgvector extension
            self.enable_pgvector_extension()
            
            # Create required enum types
            self.create_enum_types()
            
            
            logger.info("✅ Database tables created successfully")
            
        except Exception as e:
            logger.error(f"❌ Failed to initialize database: {e}")
            logger.error(f"❌ Full traceback: {traceback.format_exc()}")
            raise e

    def create_enum_types(self):
        """
        Create required enum types for the database
        """
        try:
            # Create query_frequency enum type
            result = self.session.execute(text(
                "SELECT 1 FROM pg_type WHERE typname = 'query_frequency'"
            )).fetchone()
            
            if not result:
                self.session.execute(text("""
                    CREATE TYPE query_frequency AS ENUM (
                        'hourly', 'daily', 'weekly', 'monthly'
                    )
                """))
                self.session.commit()
                logger.info("✅ Created query_frequency enum type")
            else:
                logger.info("✅ query_frequency enum type already exists")
                
        except Exception as e:
            logger.error(f"❌ Failed to create enum types: {e}")
            self.session.rollback()
            raise e
    
    def safe_commit(self):
        """
        Safely commit the session, handling PendingRollbackError.
        """
        try:
            self.session.commit()
        except PendingRollbackError:
            self.session.rollback()
            raise Exception("Transaction failed and was rolled back.")
    def enable_pgvector_extension(self):
        """
        Enable the pgvector extension required for vector operations
        """
        try:
            # Check if extension exists
            result = self.session.execute(text(
                "SELECT 1 FROM pg_extension WHERE extname = 'vector'"
            )).fetchone()
            
            if not result:
                # Enable the extension
                self.session.execute(text("CREATE EXTENSION IF NOT EXISTS vector"))
                self.session.commit()
                logger.info("✅ pgvector extension enabled")
            else:
                logger.info("✅ pgvector extension already enabled")
                
        except Exception as e:
            logger.warning(f"⚠️ Could not enable pgvector extension: {e}")
            logger.warning("Please ensure pgvector is installed in your PostgreSQL instance")
            # Don't raise the exception as the rest of the app might still work
            self.session.rollback()
    def find_nearest_title(self,product):
        # Encode the product title into a vector
        query_vector = product["title_vector"]
        query_vector = list(map(float, query_vector))  # Ensure it's a list of floats

        # Convert the query vector into a PostgreSQL-compatible array and cast it to 'vector'
        query_vector_str = ','.join(map(str, query_vector))

        # Raw SQL query
        raw_query = text(f"""
                        SELECT 
                            product_id, 
                            embedding, 
                            embedding <=> '[{query_vector_str}]'::vector AS distance  -- Using <=> for HNSW search
                        FROM 
                            product_embeddings
                        ORDER BY 
                            distance  -- Orders by closest match
                        LIMIT 5;    -- Limits the results to the top 5 closest matches
                    """)
        return self.session.execute(raw_query).first()
    def find_listing_by_ml_id(self,product):
        return self.session.query(Listings).filter(Listings.external_id == product.ml_id , Listings.marketplace_id == 1).first()
    def retrieve_queries(self,queries:list[String]):
        return self.session.query(Queries).filter(Queries.query_text.in_(queries)).all()