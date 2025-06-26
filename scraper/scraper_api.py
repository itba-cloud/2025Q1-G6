from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import asyncio
import logging
import json
from typing import Dict
from contextlib import asynccontextmanager

from botocore.config import Config
import boto3
import os

from sqs_runner import handle_message  # Re-use existing async logic
from database import Database  # Shared DB helper
from models import ClientQueries

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("scraper-api")

# SQS setup (always enabled)
SQS_QUEUE_URL = os.getenv("SQS_QUEUE_URL")
SQS_REGION = os.getenv("SQS_REGION")
sqs_client = boto3.client(
    "sqs",
    region_name=SQS_REGION,
    config=Config(retries={"max_attempts": 3})
)

app = FastAPI()

async def poll_sqs():
    while True:
        try:
            response = sqs_client.receive_message(
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
            await asyncio.sleep(5)
            continue
        logger.info(messages)
        for msg in messages:
            receipt_handle = msg["ReceiptHandle"]
            body = msg["Body"]
            await handle_message(body)
            # Delete message from queue after processing
            sqs_client.delete_message(QueueUrl=SQS_QUEUE_URL, ReceiptHandle=receipt_handle)

@asynccontextmanager
async def lifespan(app: FastAPI):
    task = asyncio.create_task(poll_sqs())
    try:
        yield
    finally:
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            logger.info("SQS polling task cancelled.")


app = FastAPI(lifespan=lifespan)

# Optionally keep health endpoint
@app.get("/scrape/health")
async def health_check():
    return {"status": "healthy"}