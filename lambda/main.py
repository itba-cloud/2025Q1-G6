import os
import json
import logging
import boto3
import uuid
from botocore.config import Config
from database import Database
from models import ClientQueries


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("scraper")

# Set up boto3 SQS client
sqs = boto3.client(
    "sqs",
    region_name=os.getenv("SQS_REGION"),  # change as needed
    config=Config(retries={"max_attempts": 3})
)
SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL")  # or hardcode it here

# Initialize global objects (if needed)
db = Database()

def lambda_handler(event, context):
    try:
        # Query the database for ClientQueries
        products = db.session.query(ClientQueries).all()
        queries = {}
        for product in products:
            query_text = product.query.query_text
            pages = product.pages_to_scrape
            if query_text in queries:
                if pages > queries[query_text]:
                    queries[query_text] = pages
            else:
                queries[query_text] = pages

        logger.info("Found queries: %s", queries)

        # For each unique query, send an SQS message
        for query_text, pages in queries.items():
            message_body = json.dumps({
                "query": query_text,
                "pages_to_scrape": pages
            })
            response = sqs.send_message(
                QueueUrl=SQS_QUEUE_URL,
                MessageBody=message_body,
                MessageGroupId="default",  # required for FIFO queues
                MessageDeduplicationId=str(uuid.uuid4())
            )
            logger.info("SQS message sent for query '%s': %s", query_text, response.get("MessageId"))

        return {
            "statusCode": 200,
            "body": json.dumps({
                "message": "SQS messages sent successfully",
                "queries": queries
            })
        }
    except Exception as e:
        logger.error("Error sending SQS messages: %s", str(e))
        return {
            "statusCode": 500,
            "body": json.dumps({
                "error": str(e)
            })
        }