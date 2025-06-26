import React from 'react'
import ReactDOM from 'react-dom/client'
import './index.css'
import App from './App.jsx'

// NEW: bootstrapAuth parses the fragment right away
import { bootstrapAuth } from './auth'

console.log("VITE_COGNITO_REDIRECT_URI", import.meta.env.VITE_COGNITO_REDIRECT_URI);
console.log("VITE_COGNITO_LOGOUT_URI", import.meta.env.VITE_COGNITO_LOGOUT_URI);
console.log("VITE_COGNITO_POOL_ID", import.meta.env.VITE_COGNITO_POOL_ID);
console.log("VITE_COGNITO_CLIENT_ID", import.meta.env.VITE_COGNITO_CLIENT_ID);
console.log("VITE_COGNITO_REGION", import.meta.env.VITE_COGNITO_REGION);
console.log("VITE_COGNITO_DOMAIN", import.meta.env.VITE_COGNITO_DOMAIN);

bootstrapAuth();

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
