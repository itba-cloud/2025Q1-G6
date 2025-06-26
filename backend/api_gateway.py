import os
import requests
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("api-gateway")

SCRAPER_URL = os.getenv("SCRAPER_URL", "http://scraper:8001")


def trigger_global_scrape():
    """Call the scraper service to schedule a scrape based on DB queries."""
    endpoint = f"{SCRAPER_URL}/scrape/schedule-from-db"
    logger.info("Triggering global scrape via %s", endpoint)
    try:
        response = requests.post(endpoint, timeout=10)
        response.raise_for_status()
        return response.json()
    except Exception as exc:
        logger.error("Failed to trigger global scrape: %s", exc)
        raise 