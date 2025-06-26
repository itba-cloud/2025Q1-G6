import asyncio
import aiohttp
import boto3
import json
import os
import pandas as pd
from sentence_transformers import SentenceTransformer
from sqlalchemy import create_engine, text
import logging
from sqlalchemy.orm import sessionmaker
from database import Database
from models import Listings, Prices, ProductCandidates, ProductEmbeddings, Products
from base.mercadolibre import MercadoLibre  # Replace with actual import
from botocore.config import Config

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("scraper")
# Set up boto3 SQS client
sqs = boto3.client(
    "sqs",
    region_name=os.getenv("SQS_REGION"),  # change as needed
    config=Config(retries={"max_attempts": 3})
)
database = Database()
SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL")  # or hardcode it here

# Initialize SentenceTransformer model once globally (avoid reloading each time)
model = SentenceTransformer('all-MiniLM-L6-v2')

async def handle_message(message_body):
    """Parse SQS message and run MercadoLibre scraper, vectorize 'title' column"""
    try:
        logging.info(f"Received message: {message_body}")
        data = message_body
        # Fix: SQS FIFO messages may double-encode the body
        if isinstance(data, str):
            data = json.loads(data)
        if isinstance(data, str):
            data = json.loads(data)
        # Support both old and new message formats
        if "queries" in data:
            queries = data["queries"]
        elif "query" in data and "pages_to_scrape" in data:
            # Single query message from Lambda
            queries = {data["query"]: data["pages_to_scrape"]}
        else:
            queries = {}
        logging.info(f"Starting scrape with queries: {queries}")
        async with aiohttp.ClientSession() as session:
            scraper = MercadoLibre(queries=queries, session=session)
            df = await scraper.perform_scrape()
            logging.info(f"Scrape completed, DataFrame shape: {df.shape}")

        # Check if 'title' column exists
        if "title" in df.columns:
            titles = df["title"].astype(str).tolist()  # Ensure all titles are strings
            embeddings = model.encode(titles, show_progress_bar=False)

            # Add embeddings as a new column (list of floats)
            df["title_vector"] = list(embeddings)
        else:
            logging.warning("Warning: 'title' column not found in scraped DataFrame.")

        await load_to_db(df)

    except Exception as e:
        logging.error(f"Error handling message: {e}")

async def close_requests_manager(rm):
    try:
        await rm.close()
    except Exception as e:
        logging.error(f"Error closing RequestsManager: {e}")

async def load_to_db(df:pd.DataFrame):
    all_new_products = []
    all_products = []
    all_product_embeddings = []
    new_candidates = []
    new_listings = []
    all_listings = {}
    safe_commit_flag = False
    query_list = []
    query_text:str
    for query_text in df["query"]:
        query_list.extend(query_text.split("-QUERYSEP-"))
    queries_objs = database.retrieve_queries(queries=query_list)
    queries_map = {q.query_text: q for q in queries_objs}
    logging.info(f"Queries map created with {len(queries_map)} entries.")
    for product in df.to_dict('records'):
        nearest_product = database.find_nearest_title(product)
        if nearest_product and nearest_product.distance < 0.15:
            nearest_product = database.session.query(Products).filter(Products.id == nearest_product.product_id).first()
        else:
            nearest_product = Products(
                name = product['title'],
            )
            all_new_products.append(nearest_product)
        all_products.append(nearest_product)
    logging.info(f"Found {len(all_products)} products to process.")
            
    if len(all_new_products) != 0:
        database.session.add_all(all_new_products)
        database.safe_commit() 
    for product in all_new_products:
        emb = ProductEmbeddings(
            product_id=product.id,
            embedding=list(map(float, model.encode(product.name, normalize_embeddings=True)))
        )
        all_product_embeddings.append(emb)
    if len(all_product_embeddings) != 0:
        database.session.add_all(all_product_embeddings)
        database.safe_commit()
    logging.info(f"Product embeddings added for {len(all_product_embeddings)} products.")
    for i, prod in enumerate(df.to_dict('records')):
        if 'ml_id' not in prod:
            logging.error(f"Error: 'ml_id' missing from DataFrame row: {prod}")
            continue
        listing = database.find_listing_by_ml_id(prod['ml_id'])
        if not listing:
            try:
                distance = all_products[i].distance
            except Exception:
                distance = 0.0
            listing = Listings(
                external_id=prod['ml_id'],
                title=prod['title'],
                url=prod['url'],
                marketplace_id=1,
                img_url=prod['img_url']
            )
            new_listings.append(listing)

            for query_text in prod['query'].split("-QUERYSEP-"):
                if query_text not in queries_map:
                    continue
                query_obj = queries_map[query_text]
                candidate = ProductCandidates(
                    query_id=query_obj.id,
                    product_id=all_products[i].id,
                    match_method='cosine',
                    distance=distance,
                    decided=False,
                    listing=listing
                )
                new_candidates.append(candidate)
        elif listing.img_url != prod['img_url']:
            listing.img_url = prod['img_url']
            safe_commit_flag = True
        all_listings[prod['ml_id']] = listing
    if new_listings:
        database.session.add_all(new_listings)
        safe_commit_flag = True
    if safe_commit_flag:
        database.safe_commit()

    for candidate in new_candidates:
        candidate.listing_id = candidate.listing.id
    if new_candidates:
        database.session.add_all(new_candidates)
        database.safe_commit()

    all_prices = []
    for prod_ml_id, listing in all_listings.items():
        # Find the corresponding product data
        prod_data = next((p for p in df.to_dict('records') if p['ml_id'] == prod_ml_id), None)
        if prod_data:
            price = Prices(
                listing_id=listing.id,
                price=float(prod_data['price'])
            )
            all_prices.append(price)
    database.session.add_all(all_prices)
    database.safe_commit()
    

async def poll_sqs():
    while True:
        try:
            response = sqs.receive_message(
                QueueUrl=SQS_QUEUE_URL,
                MaxNumberOfMessages=1,
                WaitTimeSeconds=20  # Long polling
            )
        except Exception as e:
            logger.error(f"Error polling SQS: {e}")
            await asyncio.sleep(5)  # Wait before retrying
            continue
        
        messages = response.get("Messages", [])
        if not messages:
            continue
        logger.info(messages)
        for msg in messages:
            receipt_handle = msg["ReceiptHandle"]
            body = msg["Body"]

            await handle_message(body)

            # Delete message from queue after processing
            sqs.delete_message(QueueUrl=SQS_QUEUE_URL, ReceiptHandle=receipt_handle)

if __name__ == "__main__":
    try:
        asyncio.run(poll_sqs())
    except RuntimeError as e:
        # If already in an event loop (e.g. in some ECS/Fargate setups), use alternative
        loop = asyncio.get_event_loop()
        loop.create_task(poll_sqs())
        loop.run_forever()
