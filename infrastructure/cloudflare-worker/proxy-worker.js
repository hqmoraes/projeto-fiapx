// Cloudflare Worker para proxy HTTPS dos microsserviços FIAP X
// Deploy em: https://api-proxy.fiapx.workers.dev

const MICROSERVICES = {
  auth: 'http://107.23.149.199:31404',
  upload: 'http://107.23.149.199:32159',
  processing: 'http://107.23.149.199:32382',
  storage: 'http://107.23.149.199:31627'
};

// CORS headers para permitir requisições do frontend
const CORS_HEADERS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization, Accept, Origin, User-Agent, DNT, Cache-Control, X-Mx-ReqToken, Keep-Alive, X-Requested-With, If-Modified-Since',
  'Access-Control-Max-Age': '86400',
};

export default {
  async fetch(request, env) {
    // Handle preflight requests
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 204,
        headers: CORS_HEADERS
      });
    }

    const url = new URL(request.url);
    const pathSegments = url.pathname.split('/').filter(Boolean);
    
    if (pathSegments.length === 0) {
      return new Response('FIAP X API Proxy - OK', {
        status: 200,
        headers: {
          'Content-Type': 'text/plain',
          ...CORS_HEADERS
        }
      });
    }

    const serviceName = pathSegments[0];
    const serviceUrl = MICROSERVICES[serviceName];

    if (!serviceUrl) {
      return new Response(`Service '${serviceName}' not found. Available: ${Object.keys(MICROSERVICES).join(', ')}`, {
        status: 404,
        headers: {
          'Content-Type': 'text/plain',
          ...CORS_HEADERS
        }
      });
    }

    // Build target URL
    const targetPath = '/' + pathSegments.slice(1).join('/');
    const targetUrl = serviceUrl + targetPath + url.search;

    try {
      // Forward the request
      const modifiedRequest = new Request(targetUrl, {
        method: request.method,
        headers: request.headers,
        body: request.body
      });

      const response = await fetch(modifiedRequest);
      
      // Create new response with CORS headers
      const modifiedResponse = new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: {
          ...Object.fromEntries(response.headers.entries()),
          ...CORS_HEADERS
        }
      });

      return modifiedResponse;

    } catch (error) {
      console.error('Proxy error:', error);
      
      return new Response(`Proxy error: ${error.message}`, {
        status: 502,
        headers: {
          'Content-Type': 'text/plain',
          ...CORS_HEADERS
        }
      });
    }
  }
};

// Exemplos de uso:
// https://api-proxy.fiapx.workers.dev/auth/health
// https://api-proxy.fiapx.workers.dev/auth/register
// https://api-proxy.fiapx.workers.dev/upload/upload
// https://api-proxy.fiapx.workers.dev/processing/status
// https://api-proxy.fiapx.workers.dev/storage/files
