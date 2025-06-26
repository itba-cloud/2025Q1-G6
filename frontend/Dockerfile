###############################################################################
# ── build stage – placeholder only ───────────────────────────────────────────
###############################################################################
FROM node:18-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .

# put a harmless token in the code
ARG VITE_API_URL=__VITE_API_URL__
ARG VITE_COGNITO_POOL_ID=__VITE_COGNITO_POOL_ID__
ARG VITE_COGNITO_CLIENT_ID=__VITE_COGNITO_CLIENT_ID__
ARG VITE_COGNITO_REGION=__VITE_COGNITO_REGION__
ARG VITE_COGNITO_DOMAIN=__VITE_COGNITO_DOMAIN__
ARG VITE_COGNITO_LOGOUT_URI=__VITE_COGNITO_LOGOUT_URI__
ARG VITE_COGNITO_REDIRECT_URI=__VITE_COGNITO_REDIRECT_URI__

ENV VITE_API_URL=$VITE_API_URL
ENV VITE_COGNITO_POOL_ID=$VITE_COGNITO_POOL_ID
ENV VITE_COGNITO_CLIENT_ID=$VITE_COGNITO_CLIENT_ID
ENV VITE_COGNITO_REGION=$VITE_COGNITO_REGION
ENV VITE_COGNITO_DOMAIN=$VITE_COGNITO_DOMAIN
ENV VITE_COGNITO_LOGOUT_URI=$VITE_COGNITO_LOGOUT_URI
RUN npm run build

###############################################################################
# ── runtime stage – replace token ────────────────────────────────────────────
###############################################################################
FROM node:18-alpine
WORKDIR /srv
COPY --from=build /app/dist .

# Install serve for serving static files
RUN npm install -g serve

# tiny script replaces the token with the real value **from ECS env**
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# Clipboard functionality doesn't work in Docker containers

EXPOSE 80
ENTRYPOINT ["/entrypoint.sh"]

