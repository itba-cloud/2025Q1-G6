import os

COGNITO_POOL_ID  = os.getenv("COGNITO_POOL_ID", "")
print("COGNITO_POOL_ID", COGNITO_POOL_ID)
COGNITO_CLIENT_ID = os.getenv("COGNITO_CLIENT_ID", "")
COGNITO_REGION   = os.getenv("COGNITO_REGION", "us-east-1")

COGNITO_DOMAIN = os.getenv("COGNITO_DOMAIN", "")
print("COGNITO_DOMAIN", COGNITO_DOMAIN)
if COGNITO_DOMAIN and not COGNITO_DOMAIN.startswith("http"):
    # treat it as a bare prefix
    region = os.getenv("COGNITO_REGION", "us-east-1")
    COGNITO_DOMAIN = f"https://{COGNITO_DOMAIN}.auth.{region}.amazoncognito.com"
elif not COGNITO_DOMAIN:
    pool_id = os.getenv("COGNITO_POOL_ID", "")
    region  = os.getenv("COGNITO_REGION", "us-east-1")
    COGNITO_DOMAIN = f"https://{pool_id}.auth.{region}.amazoncognito.com"

# OAuth callback as implemented by FastAPI route
REDIRECT_URI     = "/auth/callback"

# Session cookie name
COOKIE_NAME      = "session"

# Development mode - bypasses authentication when set to "true"
DEV_MODE = os.getenv("DEV_MODE", "false").lower() == "true"

# In-memory cache for Cognito JWKs.  Keys persist for the process lifetime.
JWT_KID_CACHE    = {} 