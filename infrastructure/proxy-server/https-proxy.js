#!/usr/bin/env node

// Proxy HTTPS simples para microsserviços FIAP X
// Resolve problema de Mixed Content (HTTPS frontend → HTTP backend)

const https = require('https');
const http = require('http');
const fs = require('fs');
const { createProxyMiddleware } = require('http-proxy-middleware');
const express = require('express');
const cors = require('cors');

const app = express();

// Configurar CORS para permitir requests do Amplify
app.use(cors({
  origin: ['https://main.d13ms2nooclzwx.amplifyapp.com', 'https://d13ms2nooclzwx.amplifyapp.com'],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'Accept', 'Origin'],
  credentials: true
}));

// Configurar proxies para cada microsserviço
const services = {
  auth: 'http://127.0.0.1:31404',
  upload: 'http://127.0.0.1:32159',
  processing: 'http://127.0.0.1:32382',
  storage: 'http://127.0.0.1:31627'
};

// Criar proxy para cada serviço
Object.entries(services).forEach(([name, target]) => {
  app.use(`/${name}`, createProxyMiddleware({
    target,
    changeOrigin: true,
    pathRewrite: {
      [`^/${name}`]: ''
    },
    onError: (err, req, res) => {
      console.error(`Proxy error for ${name}:`, err.message);
      res.status(502).json({ error: `Service ${name} unavailable` });
    }
  }));
});

// Health check
app.get('/health', (req, res) => {
  res.json({ 
    status: 'OK', 
    services: Object.keys(services),
    timestamp: new Date().toISOString()
  });
});

// Gerar certificado SSL auto-assinado (para desenvolvimento)
const selfsigned = require('selfsigned');
const attrs = [{ name: 'commonName', value: 'api.fiapx.local' }];
const pems = selfsigned.generate(attrs, { days: 365 });

// Iniciar servidor HTTPS
const httpsServer = https.createServer({
  key: pems.private,
  cert: pems.cert
}, app);

const PORT = process.env.PORT || 8443;

httpsServer.listen(PORT, () => {
  console.log(`🚀 FIAP X HTTPS Proxy rodando na porta ${PORT}`);
  console.log(`📡 Endpoints disponíveis:`);
  Object.keys(services).forEach(service => {
    console.log(`   https://localhost:${PORT}/${service}`);
  });
  console.log(`🔍 Health check: https://localhost:${PORT}/health`);
  console.log(`⚠️  Certificado auto-assinado - aceite o aviso do navegador`);
});

module.exports = app;
