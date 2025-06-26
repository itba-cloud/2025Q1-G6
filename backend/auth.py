from __future__ import annotations

import asyncio
import logging
from typing import Any, Dict, List, Optional

import aiohttp
import boto3
from fastapi import Depends, HTTPException, Request, Response, status
from jose import jwt
from jose.exceptions import ExpiredSignatureError, JWTError
from authlib.integrations.starlette_client import OAuth
from starlette.responses import RedirectResponse

from config import (
    COGNITO_CLIENT_ID,
    COGNITO_DOMAIN,
    COOKIE_NAME,
    JWT_KID_CACHE,
    DEV_MODE,
    COGNITO_POOL_ID,
    COGNITO_REGION,
)

logger = logging.getLogger("auth")

# ---------------------------------------------------------------------------
# OAuth client configured against the Cognito Hosted UI
# ---------------------------------------------------------------------------
oauth = OAuth()
# Only register if running with a configured user-pool id, otherwise test/dev
# environments can still start up without failing.
if COGNITO_DOMAIN and COGNITO_CLIENT_ID:
    oauth.register(
        name="cognito",
        server_metadata_url=f"{COGNITO_DOMAIN}/.well-known/openid-configuration",
        client_id=COGNITO_CLIENT_ID,
    )
else:
    logger.warning("Cognito environment variables not set – oauth client not registered. The app will run, but authentication will ALWAYS fail.")


# ---------------------------------------------------------------------------
# AWS Cognito client
# ---------------------------------------------------------------------------
cognito_client = boto3.client('cognito-idp', region_name=COGNITO_REGION) if COGNITO_REGION else None

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
async def _fetch_jwks() -> Dict[str, Any]:
    global JWT_KID_CACHE                      # keep the cache

    if JWT_KID_CACHE:                         # cache hit
        return JWT_KID_CACHE

    if not COGNITO_DOMAIN:
        logger.error("COGNITO_DOMAIN missing – cannot fetch JWKS")
        return {}

    # Use the correct Cognito Identity Provider JWKS endpoint
    # Format: https://cognito-idp.{region}.amazonaws.com/{user_pool_id}/.well-known/jwks.json
    from config import COGNITO_POOL_ID, COGNITO_REGION
    if not COGNITO_POOL_ID:
        logger.error("COGNITO_POOL_ID missing – cannot construct JWKS URL")
        return {}
    
    jwks_url = f"https://cognito-idp.{COGNITO_REGION}.amazonaws.com/{COGNITO_POOL_ID}/.well-known/jwks.json"

    logger.info("Fetching Cognito JWKs from %s", jwks_url)

    async with aiohttp.ClientSession() as session:
        async with session.get(jwks_url) as resp:
            resp.raise_for_status()           # will now be 200
            data: Dict[str, Any] = await resp.json()
            JWT_KID_CACHE = {k["kid"]: k for k in data.get("keys", [])}
            return JWT_KID_CACHE


async def _get_jwk(kid: str) -> Optional[Dict[str, Any]]:
    jwks = await _fetch_jwks()
    return jwks.get(kid)


async def _get_user_groups(username: str) -> List[str]:
    """Get user groups from Cognito using admin_list_groups_for_user API."""
    if not cognito_client or not COGNITO_POOL_ID:
        logger.error("Cognito client or pool ID not configured")
        return []
    
    try:
        # Run the synchronous boto3 call in a thread pool
        loop = asyncio.get_event_loop()
        response = await loop.run_in_executor(
            None,
            lambda: cognito_client.admin_list_groups_for_user(
                Username=username,
                UserPoolId=COGNITO_POOL_ID
            )
        )
        print("response", response)
        return [group['GroupName'] for group in response.get('Groups', [])]
    except Exception as e:
        logger.error(f"Failed to get user groups from Cognito: {e}")
        return []

# ---------------------------------------------------------------------------
# Public API used by FastAPI endpoints
# ---------------------------------------------------------------------------
async def login(request: Request):
    """Redirect unauthenticated users to the Cognito Hosted UI."""
    if not COGNITO_DOMAIN or not COGNITO_CLIENT_ID:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, detail="OAuth not configured")
    
    try:
        return await oauth.cognito.authorize_redirect(
            request,
            redirect_uri=request.url_for("auth_callback"),
            response_type="code",
        )
    except Exception as e:
        logger.error(f"Failed to connect to Cognito: {e}")
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Authentication service unavailable")


async def auth_callback(request: Request) -> Response:
    """Handle the OAuth2 code flow callback, store access token in an HttpOnly cookie."""
    if not COGNITO_DOMAIN or not COGNITO_CLIENT_ID:
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, detail="OAuth not configured")

    try:
        token = await oauth.cognito.authorize_access_token(request)
        logger.info("User authenticated via Cognito – setting session cookie")

        # Redirect home (SPA) once the cookie is set.
        resp = RedirectResponse("/")
        resp.set_cookie(
            COOKIE_NAME,
            token["access_token"],
            httponly=True,
            secure=True,
            samesite="lax",
            max_age=token.get("expires_in", 3600),
        )
        return resp
    except Exception as e:
        logger.error(f"Failed to authenticate with Cognito: {e}")
        raise HTTPException(status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Authentication service unavailable")


def get_current_user(role: str | None = None):
    """Dependency that validates JWT from the session cookie.

    Optionally enforces that *role* is present in the "cognito:groups" claim.
    """

    async def _inner(request: Request):  # type: ignore[override]
        # In development mode, bypass authentication
        if DEV_MODE:
            logger.warning("DEV_MODE enabled - bypassing authentication")
            return {"username": "dev_user", "groups": ["admins"]}
        
        # Check for Authorization header first, then fall back to cookie
        auth_header = request.headers.get("Authorization")
        token: str | None = None
        
        if auth_header and auth_header.startswith("Bearer "):
            token = auth_header[7:]  # Remove "Bearer " prefix
        else:
            token = request.cookies.get(COOKIE_NAME)
            
        if not token:
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")

        try:
            header = jwt.get_unverified_header(token)
            kid: str = header["kid"]
            jwk = await _get_jwk(kid)
            if jwk is None:
                raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Invalid token")

            claims = jwt.decode(
                token,
                jwk,
                algorithms=["RS256"],
                audience=COGNITO_CLIENT_ID,
                options={"verify_exp": True, "verify_aud": bool(COGNITO_CLIENT_ID)},
            )
            # Handle both access tokens and ID tokens
            username = claims.get("username") or claims.get("cognito:username")
            
            # Get user groups from Cognito API instead of JWT claims
            groups: List[str] = await _get_user_groups(username)
            print("groups", groups)
            
            if role and role not in groups:
                raise HTTPException(status.HTTP_403_FORBIDDEN, detail="Forbidden")
            return {"username": username, "groups": groups}
        except ExpiredSignatureError:
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Token expired") from None
        except JWTError:
            raise HTTPException(status.HTTP_401_UNAUTHORIZED, detail="Invalid token") from None

    return _inner


authenticated_user = get_current_user()
admin_required = get_current_user(role="admins")


# ---------------------------------------------------------------------------
# Logout helper – can be mounted directly in FastAPI
# ---------------------------------------------------------------------------
async def logout(response: Response):
    response.delete_cookie(COOKIE_NAME)
    return {"message": "logged out"} 