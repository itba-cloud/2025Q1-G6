import React, { useState, useEffect } from 'react'
import { login } from './login'
import axiosClient from './axiosClient'
import 'bootstrap/dist/css/bootstrap.min.css'

// Add CSS for lighter placeholder text
const placeholderStyles = `
  .form-control::placeholder,
  .form-select::placeholder {
    color: #bbb !important;
    opacity: 1;
  }
  
  .form-control::-webkit-input-placeholder,
  .form-select::-webkit-input-placeholder {
    color: #bbb !important;
  }
  
  .form-control::-moz-placeholder,
  .form-select::-moz-placeholder {
    color: #bbb !important;
    opacity: 1;
  }
  
  .form-control:-ms-input-placeholder,
  .form-select:-ms-input-placeholder {
    color: #bbb !important;
  }

  /* Eliminate horizontal gutters */
  .row,
  [class*='col-'] {
    margin-left: 0 !important;
    margin-right: 0 !important;
    padding-left: 0 !important;
    padding-right: 0 !important;
  }

  .request-card:hover {
    transform: translateY(-2px);
    cursor: pointer;
  }
`;

function App() {
  const [isLoggedIn, setIsLoggedIn] = useState(false)
  const [userProfile, setUserProfile] = useState(null)

  // App state
  const [view, setView] = useState('requests')
  const [message, setMessage] = useState('')
  const [results, setResults] = useState([])
  const [selectedQueryId, setSelectedQueryId] = useState(null)
  const [requests, setRequests] = useState([])
  const [requestsInfo, setRequestsInfo] = useState({ count: 0, limit: 5, is_admin: false })

  // For Request Creation
  const [requestForm, setRequestForm] = useState({
    query_text: '',
    frequency: 'daily',
    pages_to_scrape: 1,
  })

  // For Admin Client Creation (only shown for admins)
  const [clientForm, setClientForm] = useState({
    client_name: '',
    client_email: '',
  })
  const [clients, setClients] = useState([])

  useEffect(() => {
    // Check for tokens in URL fragment (after Cognito callback)
    const hash = window.location.hash;
    if (hash) {
      const params = new URLSearchParams(hash.substring(1)); // Remove the '#'
      const idToken = params.get('id_token');
      const accessToken = params.get('access_token');
      
      if (idToken && accessToken) {
        // Save tokens to localStorage
        localStorage.setItem('id_token', idToken);
        localStorage.setItem('access_token', accessToken);
        
        // Clean up the URL
        window.history.replaceState(null, null, window.location.pathname);
        
        setIsLoggedIn(true);
        
        // Load user profile (which will extract email properly from backend)
        setTimeout(() => {
          loadUserProfile();
        }, 100); // Small delay to ensure tokens are saved
        
        return; // Exit early since we found tokens in URL
      }
    }
    
    // Check if user is already logged in by looking for tokens in localStorage
    const storedIdToken = localStorage.getItem('id_token');
    const storedAccessToken = localStorage.getItem('access_token');
    
    if (storedIdToken && storedAccessToken) {
      setIsLoggedIn(true);
      loadUserProfile();
    }
  }, [])

  // Load user profile and set up automatic client
  const loadUserProfile = async () => {
    try {
      console.log('Loading user profile...')
      const response = await axiosClient.get('/user/profile')
      setUserProfile(response.data)
      console.log('User profile loaded:', response.data)
      
      // Load user requests after profile is loaded
      await loadUserRequests()
      
      // Load clients if user is admin
      if (response.data.is_admin) {
        await loadClients()
      }
      
      // Clear any error messages once profile is loaded successfully
      if (message.includes('Error loading')) {
        setMessage('')
      }
      
    } catch (error) {
      console.error('Error loading user profile:', error)
      
      // If token is expired or invalid, redirect to login
      if (error.response?.status === 401) {
        console.log('Token expired, redirecting to login')
        localStorage.removeItem('id_token')
        localStorage.removeItem('access_token')
        setIsLoggedIn(false)
        setUserProfile(null)
        return
      }
      
      setMessage('❌ Error loading user profile: ' + (error.response?.data?.detail || error.message))
    }
  }

  // Load user requests
  const loadUserRequests = async () => {
    try {
      const response = await axiosClient.get('/user/requests')
      setRequests(response.data.requests || [])
      setRequestsInfo({
        count: response.data.count || 0,
        limit: response.data.limit,
        is_admin: response.data.is_admin || false
      })
      console.log('User requests loaded:', response.data)
      
      if (response.data.requests.length === 0) {
        setMessage('📝 No requests found. Create your first request to start monitoring prices!')
      } else {
        setMessage('')
      }
    } catch (error) {
      console.error('Error loading user requests:', error)
      setMessage('❌ Error loading requests: ' + (error.response?.data?.detail || error.message))
    }
  }

  // Load clients (admin only)
  const loadClients = async () => {
    try {
      const response = await axiosClient.get('/client')
      setClients(response.data || [])
    } catch (error) {
      console.error('Error loading clients:', error)
    }
  }

  // Change handler for request form
  const handleRequestChange = (e) => {
    setRequestForm({ ...requestForm, [e.target.name]: e.target.value })
  }

  // Change handler for client form
  const handleClientChange = (e) => {
    setClientForm({ ...clientForm, [e.target.name]: e.target.value })
  }

  // Submit new request
  const handleRequestSubmit = async (e) => {
    e.preventDefault()
    try {
      const response = await axiosClient.post('/user/requests', {
        ...requestForm,
        pages_to_scrape: parseInt(requestForm.pages_to_scrape),
      })
      
      setMessage('✅ Request created successfully!')
      setRequestForm({ query_text: '', frequency: 'daily', pages_to_scrape: 1 })
      
      // Reload requests to show the new one
      loadUserRequests()
      
      // Switch to requests view to see the new request
      setView('requests')
      
    } catch (error) {
      setMessage('❌ Error: ' + (error.response?.data?.detail || error.message))
    }
  }

  // Submit new client (admin only)
  const handleClientSubmit = async (e) => {
    e.preventDefault()
    try {
      const response = await axiosClient.post('/client', clientForm)
      setMessage('✅ Client created successfully!')
      setClientForm({ client_name: '', client_email: '' })
      loadClients()
    } catch (error) {
      setMessage('❌ Error: ' + (error.response?.data?.detail || error.message))
    }
  }

  // Handle clicking on a request to view results
  const handleRequestClick = async (queryId) => {
    try {
      setSelectedQueryId(queryId)
      setMessage('🔄 Loading results...')
      
      const response = await axiosClient.get(`/user/requests/${queryId}/results`)
      setResults(response.data || [])
      setView('results')
      setMessage('')
      
      if (!response.data || response.data.length === 0) {
        setMessage('📦 No results found for this request yet. Results will appear after the scraper runs.')
      }
      
    } catch (error) {
      console.error('Error loading request results:', error)
      setMessage('❌ Error loading results: ' + (error.response?.data?.detail || error.message))
    }
  }

  // Trigger scraping (admin only)
  const handleTriggerScrape = async () => {
    try {
      const response = await axiosClient.post('/trigger-scrape')
      setMessage(response.data.message || 'Scrape triggered successfully!')
    } catch (error) {
      setMessage('❌ Error triggering scrape: ' + (error.response?.data?.detail || error.message))
    }
  }

  const logout = () => {
    // Clear tokens from localStorage
    localStorage.removeItem('id_token')
    localStorage.removeItem('access_token')
    setIsLoggedIn(false)
    setUserProfile(null)
    setRequests([])
    setResults([])
    
    // Optionally redirect to Cognito logout URL
    const domain = import.meta.env.VITE_COGNITO_DOMAIN
    const region = import.meta.env.VITE_COGNITO_REGION
    const clientId = import.meta.env.VITE_COGNITO_CLIENT_ID
    const logoutUri = import.meta.env.VITE_COGNITO_LOGOUT_URI || window.location.origin
    
    if (domain && region && clientId) {
      window.location.href = `https://${domain}.auth.${region}.amazoncognito.com/logout?client_id=${clientId}&logout_uri=${encodeURIComponent(logoutUri)}`
    }
  }

  if (isLoggedIn) {
    return (
      <div style={{ 
        backgroundColor: '#fff159', 
        minHeight: '100vh',
        background: 'linear-gradient(135deg, #fff159 0%, #ffeb3b 50%, #fdd835 100%)',
        width: '100vw',
        overflowX: 'hidden'
      }}>
        {/* Inject placeholder styles */}
        <style>{placeholderStyles}</style>
        
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
                <div className="text-end">
                  <div className="text-white">Welcome, {userProfile?.email || 'User'}</div>
                  {userProfile?.is_admin && (
                    <small className="text-warning">⚡ Admin Access</small>
                  )}
                  <div className="small text-light">
                    {requestsInfo.count}/{requestsInfo.limit || '∞'} requests used
                  </div>
                </div>
                <button
                  onClick={logout}
                  className="btn btn-outline-light px-4 py-2"
                  style={{ fontWeight: '600' }}
                >
                  Logout
                </button>
              </div>
            </div>
          </div>
        </div>

        <div className="container-fluid pb-5 px-0">
          {/* Navigation Cards */}
          <div className="row mb-4">
            <div className="col-12">
              <div className="d-flex justify-content-center flex-wrap gap-3">
                <button 
                  className={`btn btn-lg px-4 py-3 rounded-pill shadow-sm ${
                    view === 'requests' 
                      ? 'btn-primary text-white' 
                      : 'btn-light border-2'
                  }`}
                  style={{ 
                    fontWeight: '600',
                    transition: 'all 0.3s ease',
                    border: view === 'requests' ? '2px solid #3483fa' : '2px solid #ddd'
                  }} 
                  onClick={() => setView('requests')}
                >
                  📋 Mis Solicitudes ({requestsInfo.count})
                </button>
                <button 
                  className={`btn btn-lg px-4 py-3 rounded-pill shadow-sm ${
                    view === 'create' 
                      ? 'btn-primary text-white' 
                      : 'btn-light border-2'
                  }`}
                  style={{ 
                    fontWeight: '600',
                    transition: 'all 0.3s ease',
                    border: view === 'create' ? '2px solid #3483fa' : '2px solid #ddd'
                  }} 
                  onClick={() => setView('create')}
                >
                  ➕ Nueva Solicitud
                </button>
                {view === 'results' && (
                  <button 
                    className="btn btn-lg px-4 py-3 rounded-pill shadow-sm btn-primary text-white"
                    style={{ 
                      fontWeight: '600',
                      transition: 'all 0.3s ease',
                      border: '2px solid #3483fa'
                    }}
                  >
                    📦 Resultados
                  </button>
                )}
                {userProfile?.is_admin && (
                  <>
                    <button 
                      className={`btn btn-lg px-4 py-3 rounded-pill shadow-sm ${
                        view === 'admin-clients' 
                          ? 'btn-warning text-dark' 
                          : 'btn-outline-warning border-2'
                      }`}
                      style={{ 
                        fontWeight: '600',
                        transition: 'all 0.3s ease'
                      }} 
                      onClick={() => setView('admin-clients')}
                    >
                      👤 Administrar Clientes
                    </button>
                  {/*
                    <button 
                      className="btn btn-lg px-4 py-3 rounded-pill shadow-sm btn-outline-success border-2"
                      style={{ fontWeight: '600' }}
                      onClick={handleTriggerScrape}
                    >
                      🚀 Ejecutar Scraper
                    </button>
                  */}
                  </>
                )}
              </div>
            </div>
          </div>

          {/* Message Alert */}
          {message && (
            <div className="row mb-4">
              <div className="col-12">
                <div className="alert alert-info shadow-sm border-0 rounded-3" style={{
                  backgroundColor: message.includes('✅') ? '#d4edda' : message.includes('❌') ? '#f8d7da' : '#d1ecf1',
                  color: message.includes('✅') ? '#155724' : message.includes('❌') ? '#721c24' : '#0c5460',
                  fontSize: '1.1rem',
                  fontWeight: '500'
                }}>
                  {message}
                </div>
              </div>
            </div>
          )}

          {/* My Requests View */}
          {view === 'requests' && (
            <div className="row justify-content-center">
              <div className="col-12" style={{ maxWidth: '1200px' }}>
                <div className="card shadow-lg border-0 rounded-4" style={{ backgroundColor: 'white' }}>
                  <div className="card-header" style={{ 
                    backgroundColor: '#3483fa', 
                    color: 'white',
                    fontWeight: '600',
                    fontSize: '1.2rem',
                    borderRadius: '1.5rem 1.5rem 0 0'
                  }}>
                    📋 Mis Solicitudes de Monitoreo ({requestsInfo.count}/{requestsInfo.limit || '∞'})
                  </div>
                  <div className="card-body p-4">
                    {requests.length === 0 ? (
                      <div className="text-center py-5">
                        <div style={{ fontSize: '3rem', marginBottom: '1rem' }}>📋</div>
                        <h4 style={{ color: '#666' }}>No tienes solicitudes aún</h4>
                        <p style={{ color: '#999' }}>Crea tu primera solicitud para comenzar a monitorear precios</p>
                        <button 
                          className="btn btn-primary btn-lg px-4 py-3 rounded-pill" 
                          onClick={() => setView('create')}
                        >
                          ➕ Crear Primera Solicitud
                        </button>
                      </div>
                    ) : (
                      <div className="row">
                        {requests.map((request, index) => (
                          <div key={index} className="col-md-6 mb-3">
                            <div 
                              className="card border-0 shadow-sm rounded-3 request-card" 
                              style={{ 
                                border: '1px solid #e0e0e0',
                                transition: 'all 0.3s ease'
                              }}
                              onClick={() => handleRequestClick(request.query_id)}
                            >
                              <div className="card-body p-3">
                                <div className="d-flex justify-content-between align-items-start mb-2">
                                  <h6 className="card-title text-primary fw-bold mb-0">
                                    🔍 {request.query_text}
                                  </h6>
                                  <span className="badge bg-info text-dark fs-6 px-2 py-1 rounded-pill">
                                    ID: {request.query_id}
                                  </span>
                                </div>
                                <div className="small text-muted">
                                  <div><strong>Frecuencia:</strong> {request.frequency}</div>
                                  <div><strong>Páginas:</strong> {request.pages_to_scrape}</div>
                                  <div><strong>Creado:</strong> {new Date(request.created_at).toLocaleDateString()}</div>
                                </div>
                                <div className="mt-2">
                                  <small className="text-primary">
                                    👆 Haz clic para ver los resultados
                                  </small>
                                </div>
                              </div>
                            </div>
                          </div>
                        ))}
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Create Request Form */}
          {view === 'create' && (
            <div className="row justify-content-center">
              <div className="col-12" style={{ maxWidth: '800px' }}>
                <div className="card shadow-lg border-0 rounded-4" style={{ backgroundColor: 'white' }}>
                  <div className="card-header" style={{ 
                    backgroundColor: '#3483fa', 
                    color: 'white',
                    fontWeight: '600',
                    fontSize: '1.2rem',
                    borderRadius: '1.5rem 1.5rem 0 0'
                  }}>
                    ➕ Crear Nueva Solicitud de Monitoreo
                    {!requestsInfo.is_admin && (
                      <div className="small mt-1">
                        📊 Tienes {requestsInfo.count}/{requestsInfo.limit} solicitudes creadas
                      </div>
                    )}
                  </div>
                  <div className="card-body p-4">
                    <form onSubmit={handleRequestSubmit}>
                      <div className="row g-3">
                        <div className="col-md-12">
                          <label className="form-label fw-bold" style={{ color: '#666' }}>
                            Producto a Monitorear
                          </label>
                          <input 
                            type="text" 
                            className="form-control form-control-lg rounded-3" 
                            name="query_text" 
                            placeholder="ej: iPhone 15 Pro Max, Samsung Galaxy S24, PlayStation 5" 
                            value={requestForm.query_text}
                            onChange={handleRequestChange} 
                            required
                            style={{ border: '2px solid #e0e0e0', fontSize: '1.1rem' }}
                          />
                        </div>
                        <div className="col-md-6">
                          <label className="form-label fw-bold" style={{ color: '#666' }}>
                            Frecuencia de Monitoreo
                          </label>
                          <select 
                            className="form-select form-select-lg rounded-3" 
                            name="frequency" 
                            value={requestForm.frequency}
                            onChange={handleRequestChange} 
                            required
                            style={{ border: '2px solid #e0e0e0', fontSize: '1.1rem' }}
                          >
                            <option value="hourly">Cada hora</option>
                            <option value="daily">Diario</option>
                            <option value="weekly">Semanal</option>
                            <option value="monthly">Mensual</option>
                          </select>
                        </div>
                        <div className="col-md-6">
                          <label className="form-label fw-bold" style={{ color: '#666' }}>
                            Páginas a Escanear
                          </label>
                          <input 
                            type="number" 
                            className="form-control form-control-lg rounded-3" 
                            name="pages_to_scrape" 
                            min="1"
                            max="10"
                            value={requestForm.pages_to_scrape}
                            onChange={handleRequestChange} 
                            required
                            style={{ border: '2px solid #e0e0e0', fontSize: '1.1rem' }}
                          />
                          <small className="text-muted">Más páginas = más resultados pero más tiempo de procesamiento</small>
                        </div>
                      </div>
                      <button 
                        className="btn btn-success btn-lg mt-4 px-5 py-3 rounded-pill shadow w-100" 
                        type="submit"
                        disabled={!requestsInfo.is_admin && requestsInfo.count >= requestsInfo.limit}
                        style={{ 
                          fontWeight: '600',
                          fontSize: '1.1rem',
                          background: (!requestsInfo.is_admin && requestsInfo.count >= requestsInfo.limit) 
                            ? '#ccc' 
                            : 'linear-gradient(45deg, #00a650, #00b956)',
                          border: 'none'
                        }}
                      >
                        {(!requestsInfo.is_admin && requestsInfo.count >= requestsInfo.limit) 
                          ? '❌ Límite de solicitudes alcanzado' 
                          : '🚀 Crear Solicitud'
                        }
                      </button>
                      {!requestsInfo.is_admin && requestsInfo.count >= requestsInfo.limit && (
                        <div className="alert alert-warning mt-3">
                          <strong>⚠️ Límite alcanzado:</strong> Has creado el máximo de {requestsInfo.limit} solicitudes permitidas. 
                          Para crear una nueva, deberás contactar con el administrador.
                        </div>
                      )}
                    </form>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* View Results */}
          {view === 'results' && (
            <div className="row justify-content-center">
              <div className="col-12" style={{ maxWidth: '1200px' }}>
                <div className="card shadow-lg border-0 rounded-4" style={{ backgroundColor: 'white' }}>
                  <div className="card-header d-flex justify-content-between align-items-center" style={{ 
                    backgroundColor: '#3483fa', 
                    color: 'white',
                    fontWeight: '600',
                    fontSize: '1.2rem',
                    borderRadius: '1.5rem 1.5rem 0 0'
                  }}>
                    <span>📦 Resultados del Monitoreo</span>
                    <button 
                      className="btn btn-outline-light btn-sm"
                      onClick={() => setView('requests')}
                    >
                      ← Volver a Solicitudes
                    </button>
                  </div>
                  <div className="card-body p-4">
                    <div className="row">
                      {results.length === 0 ? (
                        <div className="col-12 text-center py-5">
                          <div style={{ fontSize: '3rem', marginBottom: '1rem' }}>📦</div>
                          <h4 style={{ color: '#666' }}>No se encontraron resultados aún</h4>
                          <p style={{ color: '#999' }}>Los resultados aparecerán después de que el scraper procese tu solicitud</p>
                        </div>
                      ) : (
                        results.map((result, index) => (
                          <div key={index} className="col-md-6 mb-3">
                            <div className="card border-0 shadow-sm rounded-3" style={{ 
                              border: '1px solid #e0e0e0',
                              transition: 'transform 0.2s ease'
                            }}>
                              <div className="card-body p-3">
                                <div className="row">
                                  <div className="col-4">
                                    <img 
                                      src={result.listings?.[0]?.img_url || 'https://via.placeholder.com/120x120?text=Sin+Imagen'} 
                                      alt={result.name || result.id} 
                                      style={{ 
                                        width: '100%',
                                        height: '120px',
                                        objectFit: 'cover',
                                        borderRadius: '8px'
                                      }}
                                    />
                                  </div>
                                  <div className="col-8">
                                    <div className="d-flex justify-content-between align-items-start mb-2">
                                      <h6 className="card-title text-primary fw-bold mb-0" style={{
                                        fontSize: '0.9rem',
                                        lineHeight: '1.2',
                                        overflow: 'hidden',
                                        display: '-webkit-box',
                                        WebkitLineClamp: 2,
                                        WebkitBoxOrient: 'vertical'
                                      }}>
                                        🛍️ {result.name || `Producto ${result.id}`}
                                      </h6>
                                    </div>
                                    <div className="small text-muted mb-2">
                                      {result.listings && result.listings.length > 0 ? (
                                        result.listings.map((listing, idx) => {
                                          const latestPrice = listing.prices && listing.prices.length > 0 
                                            ? listing.prices[listing.prices.length - 1] 
                                            : null;
                                          return (
                                            <div key={idx} className="mb-2 pb-2" style={{ borderBottom: idx < result.listings.length - 1 ? '1px solid #eee' : 'none' }}>
                                              <div className="d-flex justify-content-between align-items-center">
                                                <div>
                                                  <div><strong>Precio:</strong> ${latestPrice && latestPrice.price ? latestPrice.price.toLocaleString() : 'N/A'}</div>
                                                  <div><strong>Tienda:</strong> MercadoLibre</div>
                                                </div>
                                                <div>
                                                  <a 
                                                    href={listing.url || '#'} 
                                                    target="_blank" 
                                                    rel="noopener noreferrer" 
                                                    className="btn btn-warning btn-sm rounded-pill px-2 py-1"
                                                    style={{ 
                                                      fontWeight: '600',
                                                      fontSize: '0.7rem',
                                                      backgroundColor: '#fff159',
                                                      border: '1px solid #f57c00',
                                                      color: '#333'
                                                    }}
                                                  >
                                                    Ver
                                                  </a>
                                                </div>
                                              </div>
                                            </div>
                                          );
                                        })
                                      ) : (
                                        <div>Sin información de precio</div>
                                      )}
                                    </div>
                                  </div>
                                </div>
                              </div>
                            </div>
                          </div>
                        ))
                      )}
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* Admin Client Management */}
          {view === 'admin-clients' && userProfile?.is_admin && (
            <div className="row justify-content-center">
              <div className="col-12" style={{ maxWidth: '1000px' }}>
                <div className="card shadow-lg border-0 rounded-4" style={{ backgroundColor: 'white' }}>
                  <div className="card-header" style={{ 
                    backgroundColor: '#ff9800', 
                    color: 'white',
                    fontWeight: '600',
                    fontSize: '1.2rem',
                    borderRadius: '1.5rem 1.5rem 0 0'
                  }}>
                    👤 Administración de Clientes
                  </div>
                  <div className="card-body p-4">
                    <div className="row mb-4">
                      <div className="col-12">
                        <h5>Crear Nuevo Cliente</h5>
                        <form onSubmit={handleClientSubmit} className="row g-3">
                          <div className="col-md-6">
                            <input 
                              type="text" 
                              className="form-control" 
                              name="client_name" 
                              placeholder="Nombre del Cliente" 
                              value={clientForm.client_name}
                              onChange={handleClientChange} 
                              required
                            />
                          </div>
                          <div className="col-md-4">
                            <input 
                              type="email" 
                              className="form-control" 
                              name="client_email" 
                              placeholder="Email del Cliente" 
                              value={clientForm.client_email}
                              onChange={handleClientChange} 
                              required
                            />
                          </div>
                          <div className="col-md-2">
                            <button className="btn btn-success w-100" type="submit">
                              Crear
                            </button>
                          </div>
                        </form>
                      </div>
                    </div>
                    
                    <div className="row">
                      <div className="col-12">
                        <h5>Clientes Existentes</h5>
                        <div className="table-responsive">
                          <table className="table table-striped">
                            <thead>
                              <tr>
                                <th>ID</th>
                                <th>Nombre</th>
                                <th>Email</th>
                                <th>Fecha Creación</th>
                              </tr>
                            </thead>
                            <tbody>
                              {clients.map((client) => (
                                <tr key={client.id}>
                                  <td>{client.id}</td>
                                  <td>{client.name}</td>
                                  <td>{client.email}</td>
                                  <td>{new Date(client.created_at).toLocaleDateString()}</td>
                                </tr>
                              ))}
                            </tbody>
                          </table>
                        </div>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </div>
    )
  }

  // Login screen (unchanged)
  return (
    <div style={{ 
      backgroundColor: '#fff159', 
      minHeight: '100vh',
      background: 'linear-gradient(135deg, #fff159 0%, #ffeb3b 50%, #fdd835 100%)',
      width: '100vw',
      overflowX: 'hidden',
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center'
    }}>
      <div className="container-fluid">
        <div className="row justify-content-center">
          <div className="col-12" style={{ maxWidth: '500px' }}>
            <div className="text-center mb-5">
              <h1 style={{ 
                color: '#3483fa', 
                fontWeight: 'bold', 
                fontSize: '3.5rem',
                margin: 0,
                textShadow: '2px 2px 4px rgba(0,0,0,0.1)',
                marginBottom: '10px'
              }}>
                🛒 Mercado Scrape
              </h1>
              <p style={{ 
                color: '#666', 
                margin: 0, 
                fontSize: '1.3rem',
                fontWeight: '500'
              }}>
                Tu herramienta de análisis de precios
              </p>
            </div>
            
            <div className="card shadow-lg border-0 rounded-4" style={{ backgroundColor: 'white' }}>
              <div className="card-header text-center" style={{ 
                backgroundColor: '#3483fa', 
                color: 'white',
                fontWeight: '600',
                fontSize: '1.3rem',
                borderRadius: '1.5rem 1.5rem 0 0',
                padding: '20px'
              }}>
                🔐 Iniciar Sesión
              </div>
              <div className="card-body p-5 text-center">
                <div className="mb-4">
                  <div style={{ fontSize: '4rem', marginBottom: '1rem' }}>👋</div>
                  <h4 style={{ color: '#666', marginBottom: '1rem' }}>¡Bienvenido!</h4>
                  <p style={{ color: '#999', fontSize: '1.1rem', marginBottom: '2rem' }}>
                    Inicia sesión para acceder a tu panel de control y comenzar a monitorear precios en MercadoLibre
                  </p>
                </div>
                
                <button
                  onClick={login}
                  className="btn btn-lg px-5 py-3 rounded-pill shadow"
                  style={{ 
                    fontWeight: '600',
                    fontSize: '1.2rem',
                    background: 'linear-gradient(45deg, #3483fa, #1976d2)',
                    border: 'none',
                    color: 'white',
                    transition: 'all 0.3s ease',
                    width: '100%'
                  }}
                  onMouseOver={(e) => {
                    e.target.style.transform = 'translateY(-2px)';
                    e.target.style.boxShadow = '0 8px 25px rgba(52, 131, 250, 0.3)';
                  }}
                  onMouseOut={(e) => {
                    e.target.style.transform = 'translateY(0)';
                    e.target.style.boxShadow = '0 4px 15px rgba(0,0,0,0.1)';
                  }}
                >
                  🚀 Iniciar Sesión con Cognito
                </button>
                
                <div className="mt-4">
                  <small style={{ color: '#999' }}>
                    Autenticación segura con AWS Cognito
                  </small>
                </div>
              </div>
            </div>
            
            <div className="text-center mt-4">
              <small style={{ color: '#666', fontSize: '0.9rem' }}>
                💡 Monitorea precios • 📊 Analiza tendencias • 🎯 Toma mejores decisiones
              </small>
            </div>
          </div>
        </div>
      </div>
    </div>
  )
}

export default App
