import os, base64, urllib.parse, urllib.request, json

CLIENT_ID   = os.environ["CLIENT_ID"]
SECRET_ARN  = os.environ["CLIENT_SECRET_ARN"]
COGNITO_DOM = os.environ["COGNITO_DOMAIN"]
ALB_HOST    = os.environ["ALB_DNS"]
CALLBACK    = os.environ["CALLBACK"]
REGION      = os.environ.get("AWS_REGION", "us-east-1")

def client_secret():
    import boto3
    sm = boto3.client("secretsmanager", region_name=REGION)
    return sm.get_secret_value(SecretId=SECRET_ARN)["SecretString"]

def handler(event, _):
    # Get the path - it might be in different places depending on the event format
    path = event.get("rawPath", event.get("path", ""))
    print(f"Path: {path}")
    
    # Extract the resource path (remove stage prefix if present)
    resource_path = event.get("resource", path)
    print(f"Resource path: {resource_path}")
    
    # Handle logout - check both with and without stage prefix
    if resource_path == "/logout" or path.endswith("/logout"):
        # Simple redirect to frontend
        print("Handling logout request")
        return {
            "statusCode": 302,
            "headers": {
                "Location": f"http://{ALB_HOST}/",
                "Cache-Control": "no-cache, no-store, must-revalidate",
                "Pragma": "no-cache",
                "Expires": "0"
            }
        }
    
    # Handle callback - check both with and without stage prefix
    if resource_path == "/callback" or path.endswith("/callback"):
        query_params = event.get("queryStringParameters", {})
        print(f"Query params: {query_params}")
        
        if not query_params or "code" not in query_params:
            print("Missing authorization code")
            return {
                "statusCode": 400,
                "body": json.dumps({"error": "Missing authorization code"})
            }
        
        code = query_params["code"]
        body = urllib.parse.urlencode({
            "grant_type":    "authorization_code",
            "client_id":     CLIENT_ID,
            "client_secret": client_secret(),
            "code":          code,
            "redirect_uri":  CALLBACK,
        }).encode()
        
        req = urllib.request.Request(
            f"https://{COGNITO_DOM}/oauth2/token",
            data=body,
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        
        try:
            response = urllib.request.urlopen(req)
            tokens = json.loads(response.read())
        except Exception as e:
            print(f"Error exchanging code for tokens: {str(e)}")
            return {
                "statusCode": 500,
                "body": json.dumps({"error": str(e)})
            }
        
        # Redirect with tokens in fragment
        fragment = urllib.parse.urlencode({
            "id_token":      tokens.get("id_token", ""),
            "access_token":  tokens.get("access_token", ""),
            "expires_in":    tokens.get("expires_in", "3600"),
        })
        
        print("Successfully exchanged code for tokens, redirecting to frontend")
        return {
            "statusCode": 302,
            "headers": {
                "Location": f"{ALB_HOST}/#{fragment}",
                "Cache-Control": "no-cache, no-store, must-revalidate"
            }
        }
    
    # If we get here, it's an unknown path
    print(f"Unknown path: {path}")
    return {
        "statusCode": 404,
        "body": json.dumps({"error": "Not found"})
    }