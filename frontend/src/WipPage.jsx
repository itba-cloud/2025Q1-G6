import React from 'react';
import { useAuth } from 'react-oidc-context';

const WipPage = ({ onLogout }) => {
  const auth = useAuth();
  
  // Fallback logout function if none provided
  const handleLogout = onLogout || (() => {
    const clientIdToken = "__VITE_COGNITO_CLIENT_ID__";
    const domainToken = "__VITE_COGNITO_DOMAIN__";
    
    // Fallback if tokens weren't replaced
    const clientId = clientIdToken.includes("__VITE_") ? "3mpvm5sole4132a8thrlkp43dn" : clientIdToken;
    const cognitoDomain = domainToken.includes("__VITE_") ? "https://mercado-close-monkey.auth.us-east-1.amazoncognito.com" : domainToken;
    
    const logoutUri = window.location.origin;
    
    auth.removeUser();
    window.location.href = `${cognitoDomain}/logout?client_id=${clientId}&logout_uri=${encodeURIComponent(logoutUri)}`;
  });
  
  return (
    <div style={{ 
      backgroundColor: '#fff159', 
      minHeight: '100vh',
      background: 'linear-gradient(135deg, #fff159 0%, #ffeb3b 50%, #fdd835 100%)',
      width: '100vw',
      overflowX: 'hidden'
    }}>
      {/* Header Section */}
      <div style={{ 
        backgroundColor: '#3483fa', 
        boxShadow: '0 2px 10px rgba(0,0,0,0.1)',
        marginBottom: '30px'
      }}>
        <div className="container-fluid py-4 px-4">
          <div className="d-flex justify-content-between align-items-center">
            <div>
              <h1 style={{ 
                color: 'white', 
                fontWeight: 'bold', 
                fontSize: '2.5rem',
                margin: 0,
                textShadow: '2px 2px 4px rgba(0,0,0,0.3)'
              }}>
                🛒 Mercado Scrape
              </h1>
              <p style={{ 
                color: '#e3f2fd', 
                margin: 0, 
                fontSize: '1.1rem' 
              }}>
                Tu herramienta de análisis de precios
              </p>
            </div>
            <div className="d-flex align-items-center gap-3">
              <div style={{ color: 'white', fontSize: '1rem' }}>
                👋 {auth.user?.profile?.email || auth.user?.profile?.username || 'Usuario'}
              </div>
              <button
                onClick={handleLogout}
                className="btn btn-outline-light btn-lg rounded-pill px-4"
                style={{
                  fontWeight: '600',
                  border: '2px solid white',
                  transition: 'all 0.3s ease'
                }}
                onMouseOver={(e) => {
                  e.target.style.backgroundColor = 'white';
                  e.target.style.color = '#3483fa';
                }}
                onMouseOut={(e) => {
                  e.target.style.backgroundColor = 'transparent';
                  e.target.style.color = 'white';
                }}
              >
                🚪 Cerrar Sesión
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Content */}
      <div className="container-fluid d-flex flex-column align-items-center justify-content-center" style={{ minHeight: '60vh' }}>
        <div className="text-center">
          <h1 style={{ fontSize: '4rem', marginBottom: '2rem' }}>🚧</h1>
          <h2 style={{ color: '#3483fa', marginBottom: '1rem' }}>Work in Progress</h2>
          <p style={{ fontSize: '1.2rem', color: '#666', marginBottom: '2rem' }}>
            Estás autenticado, pero esta sección es solo para administradores.
          </p>
          <div style={{ 
            background: 'white', 
            padding: '2rem', 
            borderRadius: '15px', 
            boxShadow: '0 4px 20px rgba(0,0,0,0.1)',
            maxWidth: '500px',
            margin: '0 auto'
          }}>
            <p style={{ color: '#666', marginBottom: '1rem' }}>
              Si necesitas acceso de administrador, contacta al equipo de soporte.
            </p>
            <p style={{ color: '#999', fontSize: '0.9rem' }}>
              Usuario: <strong>{auth.user?.profile?.email || auth.user?.profile?.username}</strong>
            </p>
          </div>
        </div>
      </div>
    </div>
  );
};

export default WipPage; 