// login.js
export const login = () => {
  const domain = import.meta.env.VITE_COGNITO_DOMAIN;
  const region = import.meta.env.VITE_COGNITO_REGION;
  const clientId = import.meta.env.VITE_COGNITO_CLIENT_ID;
  const redirectUri = import.meta.env.VITE_COGNITO_REDIRECT_URI;
  
  if (!domain || !region || !clientId || !redirectUri) {
    console.error('Missing Cognito configuration');
    return;
  }
  
  const cognitoUrl = `https://${domain}.auth.${region}.amazoncognito.com/login?response_type=code&client_id=${clientId}&redirect_uri=${encodeURIComponent(redirectUri)}`;
  
  window.location.href = cognitoUrl;
}; 