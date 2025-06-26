from fastapi import FastAPI, HTTPException,Query, Depends, Request, Response
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
from api import API
from pydantic import BaseModel
from contextlib import asynccontextmanager
import asyncio
import logging
import boto3
from botocore.exceptions import ClientError, NoCredentialsError
from api_gateway import trigger_global_scrape
from auth import login as cognito_login, auth_callback, admin_required, authenticated_user, logout as logout_handler
from config import COGNITO_POOL_ID, COGNITO_REGION
import os
# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("main")

api = API()

# Initialize AWS Cognito client
def get_cognito_client():
    """Get AWS Cognito Identity Provider client"""
    try:
        return boto3.client('cognito-idp', region_name=COGNITO_REGION)
    except NoCredentialsError:
        logger.error("AWS credentials not configured")
        raise HTTPException(status_code=500, detail="AWS credentials not configured")
    except Exception as e:
        logger.error(f"Error creating Cognito client: {str(e)}")
        raise HTTPException(status_code=500, detail="Error connecting to AWS Cognito")

app = FastAPI()

print("VITE:", os.getenv("VITE_URL"))

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",  # Frontend development server
        "http://localhost:3000",  # Alternative React dev server
        "http://127.0.0.1:5173",  # Alternative localhost
        os.getenv("VITE_URL")
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

tasks = []

class QueryRequest(BaseModel):
    query_text: str
    frequency: str
    pages_to_scrape: int

class AdminQueryRequest(BaseModel):
    query_text: str
    client_id: int
    frequency: str
    pages_to_scrape: int

@app.get("/api/health")
async def health_check():
    logger.info("🏥 Health check endpoint called")
    health_status = {"status": "healthy", "message": "Service is running"}
    logger.info(f"🏥 Health check response: {health_status}")
    return health_status

@app.get("/api/")
async def hello_world():
    return {"message": "Hello, World!"}

@app.get("/api/login")
async def login_route(request: Request):
    return await cognito_login(request)

app.add_api_route("/api/auth/callback", auth_callback, methods=["GET"], name="auth_callback")

@app.post("/api/logout")
async def logout_route(response: Response):
    return await logout_handler(response)

# Work-in-progress endpoint for non-admin authenticated users
@app.get("/api/wip", dependencies=[Depends(authenticated_user)])
async def wip():
    return {"message": "🚧 Work in progress"}

# Identify current user (used by SPA AuthProvider)
@app.get("/api/me")
async def me(user=Depends(authenticated_user)):
    return user

# User-friendly endpoints for authenticated users
@app.get("/api/user/profile")
async def get_user_profile(user=Depends(authenticated_user)):
    """
    Get user profile and automatically create/get their client record.
    """
    try:
        username = user.get("username", "unknown")
        
        # Try to extract email from user info - check multiple possible JWT claims
        email = None
        if "email" in user:
            email = user["email"]
        elif "email_verified" in user:
            # Sometimes email is in a different claim
            email = user.get("email", None)
        
        # If no email found in user object, try to extract from username if it looks like an email
        if not email:
            if "@" in username:
                email = username
            else:
                # Fallback: create a placeholder email
                email = f"{username}@mercadoscrape.local"
        
        logger.info(f"Creating profile for user: {username}, email: {email}")
        
        # Get or create client for the user
        client = api.get_or_create_client_for_user(username, email)
        
        # Check if user is admin
        is_admin = "admins" in user.get("groups", [])
        
        return {
            "username": username,
            "email": email,
            "client_id": client["id"],
            "is_admin": is_admin,
            "client": client
        }
    except Exception as e:
        logger.error(f"Error getting user profile: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/user/requests")
async def get_user_requests(user=Depends(authenticated_user)):
    """
    Get all requests (queries) for the current user.
    Admins can see all requests, regular users see only their own.
    """
    try:
        # Get user profile to get client_id
        username = user.get("username", "unknown")
        email = user.get("email")
        if not email:
            if "@" in username:
                email = username
            else:
                email = f"{username}@mercadoscrape.local"
                
        client = api.get_or_create_client_for_user(username, email)
        client_id = client["id"]
        
        # Check if user is admin
        is_admin = "admins" in user.get("groups", [])
        
        # Get queries for user
        queries = api.get_queries_for_user(client_id, is_admin)
        
        return {
            "requests": queries,
            "count": len(queries),
            "limit": None if is_admin else 5,
            "is_admin": is_admin
        }
    except Exception as e:
        logger.error(f"Error getting user requests: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/user/requests")
async def create_user_request(body: QueryRequest, user=Depends(authenticated_user)):
    """
    Create a new request (query) for the current user.
    Regular users are limited to 5 active requests.
    """
    try:
        # Get user profile to get client_id
        username = user.get("username", "unknown")
        email = user.get("email")
        if not email:
            if "@" in username:
                email = username
            else:
                email = f"{username}@mercadoscrape.local"
                
        client = api.get_or_create_client_for_user(username, email)
        client_id = client["id"]
        
        # Check if user is admin
        is_admin = "admins" in user.get("groups", [])
        
        # Create query for user
        query = api.post_query_for_user(
            body.query_text, 
            client_id, 
            body.frequency, 
            body.pages_to_scrape, 
            is_admin
        )
        
        logger.info(f"Request created successfully for user {username}")
        return {"message": "Request created successfully", "query": query}
        
    except Exception as e:
        logger.error(f"Error creating user request: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/user/requests/{query_id}/results")
async def get_user_request_results(query_id: int, user=Depends(authenticated_user)):
    """
    Get results for a specific request (query).
    Regular users can only see results for their own queries.
    """
    try:
        # Get user profile to get client_id
        username = user.get("username", "unknown")
        email = user.get("email")
        if not email:
            if "@" in username:
                email = username
            else:
                email = f"{username}@mercadoscrape.local"
                
        client = api.get_or_create_client_for_user(username, email)
        client_id = client["id"]
        
        # Check if user is admin
        is_admin = "admins" in user.get("groups", [])
        
        # Get query results for user
        results = api.get_query_results_for_user(query_id, client_id, is_admin)
        
        return results
        
    except Exception as e:
        logger.error(f"Error getting user request results: {str(e)}")
        raise HTTPException(status_code=400, detail=str(e))

# Update existing admin endpoints to maintain backward compatibility
# Protect admin routes
@app.get('/api/query', dependencies=[Depends(admin_required)])
async def get_queries(client_id:int = Query(None),client_email:str = Query(None)):
    queries = api.get_queries(client_id=client_id, client_email=client_email)
    return queries

@app.get('/api/query/results', dependencies=[Depends(admin_required)])
async def get_query_results(query_id:int = Query(None)):
    results = api.get_query_results(query_id=query_id)
    return results

@app.post("/api/query", dependencies=[Depends(admin_required)])
async def create_query(body: AdminQueryRequest):
    logger.info(f"Creating query: {body}")
    try:
        query = api.post_query(body.query_text, body.client_id, body.frequency, body.pages_to_scrape)
        logger.info("Query created successfully")
        return {"message": "Query created successfully", "query": query}
    except Exception as e:
        logger.error(f"Error creating query: {str(e)}")
        return {"error": str(e)}

class ClientRequest(BaseModel):
    client_name: str
    client_email: str

@app.get("/api/client", dependencies=[Depends(admin_required)])
async def get_all_clients():
    """
    Get all clients
    """
    try:
        clients = api.get_all_clients()
        return clients
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/api/client", dependencies=[Depends(admin_required)])
async def create_client(body: ClientRequest):
    try:
        client = api.create_client(body.client_name, body.client_email)
        return {"message": "Client created successfully","client": client}
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.post("/api/trigger-scrape", dependencies=[Depends(admin_required)])
async def trigger_scrape():
    """Proxy endpoint that asks the scraper service to perform a global scrape."""
    try:
        # Run the blocking HTTP call in a thread so we do not block the asyncio loop
        response = await asyncio.to_thread(trigger_global_scrape)
        return response
    except Exception as e:
        logger.error("Error triggering scrape via scraper service: %s", e)
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/api/cognito/group/{group_name}", dependencies=[Depends(admin_required)])
async def get_cognito_group(group_name: str, user_pool_id: str = Query(default=None)):
    """
    Get information about a user group from AWS Cognito.
    
    Args:
        group_name: The name of the group to retrieve
        user_pool_id: Optional user pool ID, defaults to configured pool ID
    
    Returns:
        Group information including description, precedence, IAM role, etc.
    """
    # Use provided user_pool_id or fall back to configured one
    pool_id = user_pool_id or COGNITO_POOL_ID
    
    if not pool_id:
        raise HTTPException(status_code=400, detail="User pool ID not configured")
    
    if not group_name:
        raise HTTPException(status_code=400, detail="Group name is required")
    
    try:
        # Run the blocking AWS API call in a thread
        cognito_client = get_cognito_client()
        
        response = await asyncio.to_thread(
            cognito_client.get_group,
            GroupName=group_name,
            UserPoolId=pool_id
        )
        
        logger.info(f"Successfully retrieved group '{group_name}' from user pool '{pool_id}'")
        return response['Group']
        
    except ClientError as e:
        error_code = e.response['Error']['Code']
        error_message = e.response['Error']['Message']
        
        if error_code == 'ResourceNotFoundException':
            raise HTTPException(
                status_code=404, 
                detail=f"Group '{group_name}' not found in user pool '{pool_id}'"
            )
        elif error_code == 'InvalidParameterException':
            raise HTTPException(status_code=400, detail=f"Invalid parameter: {error_message}")
        elif error_code == 'NotAuthorizedException':
            raise HTTPException(status_code=403, detail="Not authorized to access this resource")
        elif error_code == 'TooManyRequestsException':
            raise HTTPException(status_code=429, detail="Too many requests")
        else:
            logger.error(f"AWS Cognito error: {error_code} - {error_message}")
            raise HTTPException(status_code=500, detail=f"AWS Cognito error: {error_message}")
            
    except Exception as e:
        logger.error(f"Unexpected error retrieving group '{group_name}': {str(e)}")
        raise HTTPException(status_code=500, detail="Internal server error")


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)

