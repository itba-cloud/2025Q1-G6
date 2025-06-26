import asyncio
from models import *

from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.declarative import declarative_base
# Attempt to import heavy ML model only if available (scraper image)
try:
    from sentence_transformers import SentenceTransformer  # type: ignore
except ModuleNotFoundError:
    SentenceTransformer = None  # type: ignore
# Heavy scraper dependencies are only available in the scraper image
try:
    from base.mercadolibre import MercadoLibre  # type: ignore
except ModuleNotFoundError:
    MercadoLibre = None  # type: ignore
from sqlalchemy import select
from sqlalchemy.exc import PendingRollbackError
import os

from dotenv import load_dotenv
import os
from sqlalchemy.orm import class_mapper
import logging
import traceback

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("api")

def serialize_model(model):
    """
    Serialize a SQLAlchemy model instance into a dictionary.
    """
    columns = [column.key for column in class_mapper(model.__class__).columns]
    return {column: getattr(model, column) for column in columns}
# Create a database engine
class API():
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
        
        try:
            # Only load the model when the package is present (not in the thin-backend image)
            if SentenceTransformer is not None:
                self.model = SentenceTransformer('all-MiniLM-L6-v2')
                logger.info("✅ SentenceTransformer model loaded successfully")
            else:
                self.model = None
                logger.info("ℹ️  SentenceTransformer not available in this image – relying on scraper service for embeddings")
        except Exception as e:
            logger.error(f"❌ Failed to load SentenceTransformer model: {e}")
            logger.error(f"❌ Error type: {type(e).__name__}")
            logger.error(f"❌ Full traceback: {traceback.format_exc()}")

    def initialize_database(self):
        """
        Initialize database tables and basic data
        """
        try:
            # Enable pgvector extension
            self.enable_pgvector_extension()
            
            # Create required enum types
            self.create_enum_types()
            
            # Create all tables
            Base.metadata.create_all(self.engine)
            logger.info("✅ Database tables created successfully")
            
            # Check if basic data exists, if not create it
            self.create_basic_data()
            
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

    def create_basic_data(self):
        """
        Create basic required data like marketplaces
        """
        try:
            # Check if MercadoLibre marketplace exists
            ml_marketplace = self.session.query(Marketplaces).filter(
                Marketplaces.name == 'MercadoLibre'
            ).first()
            
            if not ml_marketplace:
                ml_marketplace = Marketplaces(
                    name='MercadoLibre',
                    region='Argentina',
                    domain='mercadolibre.com.ar'
                )
                self.session.add(ml_marketplace)
                self.session.commit()
                logger.info("✅ Created MercadoLibre marketplace entry")
            
        except Exception as e:
            logger.error(f"❌ Failed to create basic data: {e}")
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
    def get_query_results(self, query_id:int):
        query = text(f"""
        SELECT l.id,l.external_id,l.title,l.url,p.price,p.scraped_at,pro.name,pro.created_at,l.img_url,
                     l.created_at,l.last_seen
        FROM product_candidates pc
        INNER JOIN products pro ON pc.product_id = pro.id
        INNER JOIN listings l ON pc.listing_id = l.id
        INNER JOIN prices p ON l.id = p.listing_id
        WHERE pc.query_id = {query_id}
        """)
        try:
            result = self.session.execute(query).fetchall()
            # Convert the result to a list of dictionaries
            products = dict()

            for row in result:
                product_id = row[6]
                if product_id in products:
                    listings = products[product_id]["listings"]
                else:
                    products[product_id] = {
                        "id": product_id,
                        "name": row[7],
                        "listings": dict()
                    }
                    listings = products[product_id]["listings"]
                
                if row[0] in listings:
                    listings[row[0]]["prices"].append({"price": row[4], "created_at": row[5]})
                else:
                    listing = {
                        "id": row[0],
                        "external_id": row[1],
                        "title": row[2],
                        "url": row[3],
                        "img_url": row[8],	
                        "created_at": row[9],
                        "last_seen": row[10],
                        "prices":[
                            {"price": row[4], "created_at": row[5]}
                        ]
                    }
                    listings[row[0]] = listing
            for key in products:
                products[key]["listings"] = list(products[key]["listings"].values())
            return list(products.values())
                    
        except Exception as e:
            self.session.rollback()
            raise e

    def get_queries(self, client_id=None,client_email=None):
        queries = self.session.query(Queries)

        if client_id or client_email:
            # Join with ClientQueries to include additional fields
            if client_id:
                queries = (
                    queries.join(ClientQueries)
                    .filter(ClientQueries.client_id == client_id)
                    .with_entities(
                        Queries.query_text,
                        ClientQueries.pages_to_scrape,
                        ClientQueries.frequency,
                        Queries.created_at,
                        Queries.removed_at,
                        Queries.id
                    )
                )
            else:
                queries = (
                    queries.join(ClientQueries)
                    .join(Clients)
                    .filter(Clients.email == client_email)
                    .with_entities(
                        Queries.query_text,
                        ClientQueries.pages_to_scrape,
                        ClientQueries.frequency,
                        Queries.created_at,
                        Queries.removed_at,
                        Queries.id
                    )
                )
            # Convert the result to a list of dictionaries
            result = [
                {
                    "query_text": query_text,
                    "pages_to_scrape": pages_to_scrape,
                    "frequency": frequency,
                    "created_at": created_at,
                    "removed_at": removed_at,
                    "query_id": id
                }
                for query_text, pages_to_scrape, frequency,created_at,removed_at,id in queries.all()
            ]
        else:
            # If no client_id is provided, return only the query text
            queries = queries.with_entities(Queries.query_text,
                                            Queries.created_at,
                                            Queries.removed_at,
                                            Queries.id)
            # Convert the result to a list of dictionaries
            result = [{"query_text": query_text,
                       "created_at": created_at,
                    "removed_at": removed_at,
                     "query_id":id } for query_text,created_at,removed_at,id in queries.all()]

        return result
    
    def get_all_clients(self):
        """
        Get all clients from the database
        """
        try:
            clients = self.session.query(Clients).all()
            return [serialize_model(client) for client in clients]
        except Exception as e:
            self.session.rollback()
            raise e

    def create_client(self, client_name: str, client_email: str)->dict:
        try:
            client = self.session.query(Clients).filter(Clients.email == client_email).first()
            if not client:
                client = Clients(
                    name=client_name,
                    email=client_email
                )
                self.session.add(client)
                self.safe_commit()  # Use safe_commit to handle rollback
            else:
                raise Exception('Client already exists')
            return serialize_model(client)
        except Exception as e:
            self.session.rollback()
            raise e

    def post_query(self, query_text, client_id, frequency, pages_to_scrape)-> ClientQueries:
        try:
            query = self.session.query(Queries).filter(Queries.query_text == query_text).first()
            if not query:
                query = Queries(
                    query_text=query_text
                )
                self.session.add(query)
                self.safe_commit()  # Use safe_commit to handle rollback

            client_query = self.session.query(ClientQueries).filter(
                ClientQueries.client_id == client_id,
                ClientQueries.query_id == query.id
            ).first()
            if client_query:
                raise Exception('Query already exists')
            client_query = ClientQueries(
                client_id=client_id,
                query_id=query.id,
                frequency=frequency,
                pages_to_scrape=pages_to_scrape
            )
            self.session.add(client_query)
            self.safe_commit()  # Use safe_commit to handle rollback
            return client_query
        except Exception as e:
            self.session.rollback()
            raise e
       
    async def get_listings(self, client_id:int):
        # Fetch the queries for the given client_id

        f"""
        SELECT * FROM client_queries cq
        INNER JOIN queries q 
        WHERE client_id = {client_id}
        
        """
        queries = self.session.query(ClientQueries).filter(ClientQueries.client_id == client_id).all()
        if not queries:
            return {"error": "No queries found for the given client_id"}
        
        # Create a dictionary to hold the listings for each query
        listings_dict = {}
        
        # Iterate through each query and fetch the corresponding listings
        for client_query in queries:
            query = self.session.query(Queries).filter(Queries.id == client_query.query_id).first()
            if query:
                listings = self.session.query(Listings).filter(Listings.external_id == query.query_text).all()
                listings_dict[query.query_text] = [listing.title for listing in listings]
        
        return listings_dict
        
    async def scrape_all(self):
        try:
            all_new_products = []
            all_products = []
            all_product_embeddings = []

            products = self.session.query(ClientQueries).all()
            queries = {}
            # Print the fetched products
            for product in products:
                if product.query.query_text in queries:
                    if product.pages_to_scrape > queries[product.query.query_text]:
                        queries[product.query.query_text] = product.pages_to_scrape
                else:
                    queries[product.query.query_text] = product.pages_to_scrape

            scraper = MercadoLibre(queries=queries)
            await scraper.scrape()
            await scraper.session.close()


            for product in scraper.data.itertuples(index=False):
                nearest_product = self.find_nearest_title(product)
                if nearest_product and nearest_product.distance < 0.15:
                    nearest_product = self.session.query(Products).filter(Products.id == nearest_product.product_id).first()
                else:
                    nearest_product = Products(
                        name = product.title,
                    )
                    all_new_products.append(nearest_product)
                all_products.append(nearest_product)
                        
                    
            if len(all_new_products) != 0:
                self.session.add_all(all_new_products)
                self.safe_commit() 
            for product in all_new_products:
                emb = ProductEmbeddings(
                    product_id = product.id,
                    embedding = list(map(float,self.model.encode(product.name, normalize_embeddings=True)))
                )
                all_product_embeddings.append(emb)
            if len(all_product_embeddings) != 0:
                self.session.add_all(all_product_embeddings)
                self.safe_commit()

            queries = self.session.query(Queries).filter(Queries.query_text.in_(queries.keys())).all()
            queries = {query.query_text: query for query in queries}
            new_candidates = []
            new_listings = []
            all_listings = {}
            safe_commit = False
            for i,product in enumerate(scraper.data.itertuples(index=False)):
                listing = self.find_listing_by_ml_id(product)
                if not listing:
                    try:
                        distance = all_products[i].distance
                    except:
                        distance = 0.0
                    listing = Listings(
                        external_id = product.ml_id,
                        title = product.title,
                        url = product.url,
                        marketplace_id = 1,
                        img_url = product.img_url
                    )
                    new_listings.append(listing)
                    
                    for query in product.query.split("-QUERYSEP-"):
                        if query not in queries:
                            continue
                        query = queries[query]
                        candidate = ProductCandidates(
                            query_id = query.id,
                            product_id = all_products[i].id,
                            match_method = 'cosine',
                            distance = distance,
                            decided = False,
                            listing = listing
                        )
                        new_candidates.append(candidate)
                elif listing.img_url != product.img_url:
                    listing.img_url = product.img_url
                    safe_commit = True
                all_listings[product] = listing
            if len(new_listings) != 0:
                self.session.add_all(new_listings)
                safe_commit = True
            if safe_commit:
                self.safe_commit()
            
            for candidate in new_candidates:    
                candidate.listing_id = candidate.listing.id
            if len(new_candidates) != 0:
                self.session.add_all(new_candidates)
                self.safe_commit()

            all_prices = []
            for product,listing in all_listings.items():
                price = Prices(
                    listing_id = listing.id,
                    price = float(product.price)
                )
                all_prices.append(price)
            self.session.add_all(all_prices)
            self.safe_commit()  # Use safe_commit to handle rollback
        except Exception as e:
            self.session.rollback()
            raise e

    def find_listing_by_ml_id(self,product):
        return self.session.query(Listings).filter(Listings.external_id == product.ml_id , Listings.marketplace_id == 1).first()
    def find_nearest_title(self,product):
        # Encode the product title into a vector
        query_vector = self.model.encode(product.title, normalize_embeddings=True)
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
    def __del__(self):
        # rollback any uncommitted transactions
        try:
            self.session.rollback()
        except Exception as e:
            logger.error(f"Error during rollback: {e}")
        # Close the session and dispose of the engine
        try:
            self.session.close()
            self.engine.dispose()
        except Exception as e:
            logger.error(f"Error during session close: {e}")

        logger.info("Session closed and engine disposed.")

    def get_or_create_client_for_user(self, username: str, user_email: str) -> dict:
        """
        Get or create a client for a user automatically.
        If client doesn't exist, create it with username as name and user email.
        """
        try:
            # First try to find by email
            client = self.session.query(Clients).filter(Clients.email == user_email).first()
            if not client:
                # Create new client for the user
                client = Clients(
                    name=username,
                    email=user_email
                )
                self.session.add(client)
                self.safe_commit()
                logger.info(f"✅ Auto-created client for user: {username} ({user_email})")
            
            return serialize_model(client)
            
        except Exception as e:
            self.session.rollback()
            logger.error(f"❌ Error getting/creating client for user {username}: {e}")
            raise e

    def get_user_query_count(self, client_id: int) -> int:
        """
        Get the number of active queries for a client (user).
        """
        try:
            count = self.session.query(ClientQueries).filter(
                ClientQueries.client_id == client_id,
                ClientQueries.removed_at.is_(None)
            ).count()
            return count
        except Exception as e:
            logger.error(f"❌ Error getting user query count: {e}")
            return 0

    def get_queries_for_user(self, client_id: int, is_admin: bool = False):
        """
        Get queries for a specific user/client. 
        If is_admin=True, can see all queries, otherwise only their own.
        """
        try:
            if is_admin:
                # Admin can see all queries with client information
                queries = self.session.query(ClientQueries).join(Queries).join(Clients).filter(
                    ClientQueries.removed_at.is_(None)
                ).with_entities(
                    Queries.query_text,
                    ClientQueries.pages_to_scrape,
                    ClientQueries.frequency,
                    Queries.created_at,
                    Queries.removed_at,
                    Queries.id.label('query_id'),
                    ClientQueries.id.label('client_query_id'),
                    ClientQueries.client_id,
                    Clients.name.label('client_name'),
                    Clients.email.label('client_email')
                ).all()
                
                result = [
                    {
                        "query_text": row.query_text,
                        "pages_to_scrape": row.pages_to_scrape,
                        "frequency": row.frequency,
                        "created_at": row.created_at,
                        "removed_at": row.removed_at,
                        "query_id": row.query_id,
                        "client_query_id": row.client_query_id,
                        "client_id": row.client_id,
                        "client_name": row.client_name,
                        "client_email": row.client_email
                    }
                    for row in queries
                ]
            else:
                # Regular user can only see their own queries
                queries = self.session.query(ClientQueries).join(Queries).filter(
                    ClientQueries.client_id == client_id,
                    ClientQueries.removed_at.is_(None)
                ).with_entities(
                    Queries.query_text,
                    ClientQueries.pages_to_scrape,
                    ClientQueries.frequency,
                    Queries.created_at,
                    Queries.removed_at,
                    Queries.id.label('query_id'),
                    ClientQueries.id.label('client_query_id')
                ).all()
                
                result = [
                    {
                        "query_text": row.query_text,
                        "pages_to_scrape": row.pages_to_scrape,
                        "frequency": row.frequency,
                        "created_at": row.created_at,
                        "removed_at": row.removed_at,
                        "query_id": row.query_id,
                        "client_query_id": row.client_query_id
                    }
                    for row in queries
                ]
            
            return result
            
        except Exception as e:
            logger.error(f"❌ Error getting queries for user: {e}")
            self.session.rollback()
            raise e

    def post_query_for_user(self, query_text: str, client_id: int, frequency: str, pages_to_scrape: int, is_admin: bool = False) -> ClientQueries:
        """
        Create a query for a specific user with role-based limits.
        Regular users are limited to 5 active queries.
        """
        try:
            # Check query limit for regular users
            if not is_admin:
                current_count = self.get_user_query_count(client_id)
                if current_count >= 5:
                    raise Exception('Users are limited to 5 active queries. Please remove an existing query before creating a new one.')
            
            # Check if query already exists
            query = self.session.query(Queries).filter(Queries.query_text == query_text).first()
            if not query:
                query = Queries(query_text=query_text)
                self.session.add(query)
                self.safe_commit()

            # Check if this specific client-query combination already exists
            existing_client_query = self.session.query(ClientQueries).filter(
                ClientQueries.client_id == client_id,
                ClientQueries.query_id == query.id,
                ClientQueries.removed_at.is_(None)
            ).first()
            
            if existing_client_query:
                raise Exception('This query already exists for your account')
            
            # Create the client-query relationship
            client_query = ClientQueries(
                client_id=client_id,
                query_id=query.id,
                frequency=frequency,
                pages_to_scrape=pages_to_scrape
            )
            self.session.add(client_query)
            self.safe_commit()
            
            return client_query
            
        except Exception as e:
            self.session.rollback()
            logger.error(f"❌ Error creating query for user: {e}")
            raise e

    def get_query_results_for_user(self, query_id: int, client_id: int, is_admin: bool = False):
        """
        Get query results for a specific user. 
        Regular users can only see results for their own queries.
        """
        try:
            # First, verify that the user has access to this query
            if not is_admin:
                # Check if this query belongs to the user
                client_query = self.session.query(ClientQueries).filter(
                    ClientQueries.client_id == client_id,
                    ClientQueries.removed_at.is_(None)
                ).join(Queries).filter(Queries.id == query_id).first()
                
                if not client_query:
                    raise Exception('Query not found or you do not have permission to view it')
            
            # Get the results using the existing method
            return self.get_query_results(query_id)
            
        except Exception as e:
            logger.error(f"❌ Error getting query results for user: {e}")
            raise e

if __name__ == "__main__":
    api = API()
    asyncio.run(api.scrape_all())
