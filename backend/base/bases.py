import requests
from bs4 import BeautifulSoup
from abc import ABC, abstractmethod
import pandas as pd
import asyncio
import aiohttp
import random
import time
import json
import os
import dotenv
dotenv.load_dotenv()

class BaseScraper(ABC):
    def __init__(self):
        self.start_time = None
        self.end_time = None
        self.runs = []
        self.data:pd.DataFrame = pd.DataFrame()
    
    def start_timer(self):
        """
        Starts a timer to measure how long the scraping takes.
        """
        self.start_time = time.time()

    def end_timer(self):
        """
        Ends the timer and calculates the elapsed time.
        """
        self.end_time = time.time()
        elapsed_time = self.end_time - self.start_time
        self.runs.append(elapsed_time)
    def average_time(self):
        return sum(self.runs) / len(self.runs)

    async def scrape(self):
        """
        Wraps the actual scraping logic with a timer.
        """
        self.start_timer()
        result = await self.perform_scrape()
        self.end_timer()
        return result

    @abstractmethod
    async def perform_scrape(self):
        """
        Abstract method for actual scraping logic to be implemented by subclasses.
        """
        pass

class RequestsManager(BaseScraper):
    def __init__(self, headers=None,queries:dict = {}, session:aiohttp.ClientSession = None,requests_per_minute = 1000,request_type="json",requires_proxies=False):
        super().__init__()
       

        self.queries:dict = queries
        self.headers = headers if headers else {'User-Agent': 'Mozilla/5.0'}
        self.delay = 60 / requests_per_minute 
        self.tasks = []
        self.last_run = None
        self.requires_proxies = requires_proxies
        self.semaphore = asyncio.Semaphore(10)
        self.body = None
        self.session:aiohttp.ClientSession = session if session else aiohttp.ClientSession()
        self.session_declared = True if session else False
    def get_user_agent(self):
        """
        Returns a random User-Agent string from a predefined list.
        """
        with open('./base/user-agents.txt', 'r') as f:
            user_agents = f.readlines()
        return random.choice(user_agents).strip()
    async def fetch_json(self, url, payload=None, retries=10,is_get=True):
        content = await self.fetch_content(url,payload,retries,is_get=is_get)
        return content
    async def fetch_html(self, url, payload=None, retries=10,extra_data=None):
        content = await self.fetch_content(url,payload,retries,is_get=True,isHTML=True)
        return content, extra_data
    async def fetch_content(self, url,payload=None,retries=10,is_get=True,isHTML=False):
        """
        Fetches the json content of the given URL.
        """
        PROXY_KEY = os.getenv("PROXY_KEY")
        proxy = f'http://brd-customer-hl_ac97a42b-zone-mercado_scraper:{PROXY_KEY}@brd.superproxy.io:33335' if self.requires_proxies else None
        for attempt in range(retries):
            async with self.semaphore :
              
                await asyncio.sleep(self.delay + random.uniform(0, 5))  # Random delay between requests
                try:
                    if is_get:
                        req_type = self.session.get
                    else:
                        req_type = self.session.post
                    headers = self.headers.copy()
                    headers['User-Agent'] = self.get_user_agent()
                    async with req_type(url,data=payload, headers=headers, ssl=False, proxy=proxy,timeout=600,json=self.body) as response:
                        response.raise_for_status()
                        if isHTML:
                            return self.parse_html(await response.text())
                        else:
                            return await response.json()

                except (aiohttp.ClientError, aiohttp.ClientHttpProxyError,aiohttp.ClientPayloadError) as e:
                    error_message = str(e)
                    #print(f"Error fetching content from {url} with proxy {proxy}: {error_message}\n headers:{e.headers}") if "Internal Server Error" in error_message else None

                    if attempt == retries - 1:
                        return None
                    await asyncio.sleep(attempt)  # Exponential backoff
                except TimeoutError:
                    self.session = aiohttp.ClientSession()
            
            
                

    def parse_html(self, html_content):
        """
        Parses HTML content using BeautifulSoup.
        """
        if html_content:
            return BeautifulSoup(html_content, 'html.parser')
        return None
    
    def find_elements(self, soup, tag, class_name=None, id_name=None):
        """
        Finds elements by tag, class, or ID.
        """
        if not soup:
            return []
        if class_name:
            return soup.find_all(tag, class_=class_name)
        if id_name:
            return soup.find_all(tag, id=id_name)
        return soup.find_all(tag)
    async def close(self):
        """
        Closes the aiohttp session.
        """
        if self.session_declared:
            await self.session.close()
            self.session_declared = False
        else:
            print("Session not declared, cannot close")
    def __del__(self):
        if not self.session_declared:
            asyncio.run(self.close())
        else:
            print("Session not closed, declared outside of the class")
