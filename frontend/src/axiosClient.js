// src/axiosClient.js
import axios from 'axios';

// VITE_API_URL is injected at runtime via entrypoint.sh
// The build uses a placeholder token that gets replaced with the actual URL from ECS environment
const backendUrl = import.meta.env.VITE_API_URL || 'http://localhost:8000';

const axiosClient = axios.create({
  baseURL: backendUrl,
  headers: {
    'Content-Type': 'application/json'
  }
});

// Function to get the current auth context (will be set by the app)
let getAuthContext = null;

export function setAuthContext(authContextGetter) {
  getAuthContext = authContextGetter;
}

// Optionally, you can add interceptors for requests/responses
axiosClient.interceptors.request.use(
  (config) => {
    // 1️⃣  Prefer a supplied auth context …
    if (getAuthContext) {
      const auth = getAuthContext();
      if (auth?.isAuthenticated && auth.user?.access_token) {
        config.headers.Authorization = `Bearer ${auth.user.access_token}`;
        return config;
      }
    }

    // 2️⃣  …else fall back to the one we stashed in localStorage
    const token = localStorage.getItem("access_token");
    if (token) {
      config.headers.Authorization = `Bearer ${token}`;
    }
    return config;
  },
  (error) => Promise.reject(error)
);

axiosClient.interceptors.response.use(
  (response) => response,
  (error) => {
    // Log the error for debugging
    console.log('API Error:', error.response?.status, error.response?.data);
    return Promise.reject(error);
  }
);

export default axiosClient;

