#!/bin/bash
set -e

echo "🔧 Injecting VITE_API_URL: ${VITE_API_URL}"
echo "🔧 Injecting VITE_COGNITO_POOL_ID: ${VITE_COGNITO_POOL_ID}"
echo "🔧 Injecting VITE_COGNITO_CLIENT_ID: ${VITE_COGNITO_CLIENT_ID}"
echo "🔧 Injecting VITE_COGNITO_REGION: ${VITE_COGNITO_REGION}"
echo "🔧 Injecting VITE_COGNITO_DOMAIN: ${VITE_COGNITO_DOMAIN}"
echo "🔧 Injecting VITE_COGNITO_REDIRECT_URI: ${VITE_COGNITO_REDIRECT_URI}"
echo "🔧 Injecting VITE_COGNITO_LOGOUT_URI: ${VITE_COGNITO_LOGOUT_URI}"

# patch every JS chunk in-place
# find /srv -name '*.js' -exec \
#   sed -i "s|__VITE_API_URL__|${VITE_API_URL}|g" {} +
# find /srv -name '*.js' -exec \
#   sed -i "s|__VITE_COGNITO_POOL_ID__|${VITE_COGNITO_POOL_ID}|g" {} +
# find /srv -name '*.js' -exec \
#   sed -i "s|__VITE_COGNITO_CLIENT_ID__|${VITE_COGNITO_CLIENT_ID}|g" {} +
# find /srv -name '*.js' -exec \
#   sed -i "s|__VITE_COGNITO_REGION__|${VITE_COGNITO_REGION}|g" {} +
# find /srv -name '*.js' -exec \
#   sed -i "s|__VITE_COGNITO_DOMAIN__|${VITE_COGNITO_DOMAIN}|g" {} +
# find /srv -name '*.js' -exec \
#   sed -i "s|__VITE_COGNITO_LOGOUT_URI__|${VITE_COGNITO_LOGOUT_URI}|g" {} +
# find /srv -name '*.js' -exec \
#   sed -i "s|__VITE_COGNITO_REDIRECT_URI__|${VITE_COGNITO_REDIRECT_URI}|g" {} 
# 
echo "=== Starting deploy script in: $(pwd)"

cd ../frontend || { echo "Failed to cd ../frontend"; exit 1; }
echo "=== Now in: $(pwd)"

npm install

echo "=== Building the Vite app with VITE_API_URL=$VITE_API_URL ..."
VITE_API_URL=${VITE_API_URL} VITE_COGNITO_POOL_ID=${VITE_COGNITO_POOL_ID} VITE_COGNITO_CLIENT_ID=${VITE_COGNITO_CLIENT_ID} VITE_COGNITO_REGION=${VITE_COGNITO_REGION} VITE_COGNITO_DOMAIN=${VITE_COGNITO_DOMAIN} VITE_COGNITO_REDIRECT_URI=${VITE_COGNITO_REDIRECT_URI} VITE_COGNITO_LOGOUT_URI=${VITE_COGNITO_LOGOUT_URI} npm run build

echo "=== Listing dist folder contents..."
ls -l dist

echo "=== Done!"