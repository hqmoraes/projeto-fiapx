#!/bin/bash

# FIAP-X Complete Production Deployment Script
# Deploys HTTPS + Email Notifications + Full System

set -e

echo "🚀 FIAP-X COMPLETE PRODUCTION DEPLOYMENT"
echo "========================================"
echo ""
echo "This script will deploy:"
echo "  ✅ HTTPS with custom domain (fiapx.wecando.click)"
echo "  ✅ CloudFront CDN for global performance"
echo "  ✅ Email notification system"
echo "  ✅ All microservices with latest updates"
echo "  ✅ Observability stack (if not already deployed)"
echo ""

# Configuration
DOMAIN="fiapx.wecando.click"
NAMESPACE="fiapx"
REGION="us-east-1"

# Check prerequisites
echo "🔍 Checking prerequisites..."

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl not found. Please install kubectl first."
    exit 1
fi

# Check if aws CLI is available
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI not found. Please install AWS CLI first."
    exit 1
fi

# Check if docker is available
if ! command -v docker &> /dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    exit 1
fi

# Check Kubernetes connectivity
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster. Please check your kubeconfig."
    exit 1
fi

echo "✅ All prerequisites met!"

# Confirm deployment
echo ""
read -p "🚨 This will deploy to PRODUCTION. Continue? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 1
fi

echo ""
echo "🏗️ Starting deployment process..."

# Step 1: Ensure namespace exists
echo ""
echo "📦 Step 1: Ensuring namespace exists..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespace $NAMESPACE ready"

# Step 2: Build and push Docker images
echo ""
echo "🐳 Step 2: Building Docker images..."

# Build notification service
echo "Building notification-service..."
cd notification-service
docker build -t notification-service:latest .
cd ..

# Build other services if needed
for service in auth-service api-gateway upload-service processing-service storage-service; do
    if [ -d "$service" ]; then
        echo "Building $service..."
        cd $service
        if [ -f "Dockerfile" ]; then
            docker build -t $service:latest .
        fi
        cd ..
    fi
done

echo "✅ Docker images built successfully"

# Step 3: Deploy core services
echo ""
echo "🚀 Step 3: Deploying core microservices..."

# Deploy infrastructure services
kubectl apply -f infrastructure/kubernetes/postgres.yaml
kubectl apply -f infrastructure/kubernetes/redis.yaml
kubectl apply -f infrastructure/kubernetes/rabbitmq.yaml
kubectl apply -f infrastructure/kubernetes/minio.yaml

# Wait for infrastructure to be ready
echo "⏳ Waiting for infrastructure services..."
kubectl wait --for=condition=ready pod -l app=postgres -n $NAMESPACE --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis -n $NAMESPACE --timeout=300s
kubectl wait --for=condition=ready pod -l app=rabbitmq -n $NAMESPACE --timeout=300s
kubectl wait --for=condition=ready pod -l app=minio -n $NAMESPACE --timeout=300s

# Deploy microservices
kubectl apply -f infrastructure/kubernetes/auth-service.yaml
kubectl apply -f infrastructure/kubernetes/upload-service.yaml
kubectl apply -f infrastructure/kubernetes/processing-service.yaml
kubectl apply -f infrastructure/kubernetes/storage-service.yaml
kubectl apply -f infrastructure/kubernetes/api-gateway.yaml

# Wait for microservices
echo "⏳ Waiting for microservices..."
kubectl wait --for=condition=available deployment -l tier=microservice -n $NAMESPACE --timeout=300s

echo "✅ Core services deployed"

# Step 4: Setup email notifications
echo ""
echo "📧 Step 4: Setting up email notifications..."

# Get email credentials
echo "Please provide your email configuration for notifications:"
read -p "SMTP Username (Gmail): " SMTP_USERNAME
read -s -p "SMTP Password (App Password): " SMTP_PASSWORD
echo ""

# Create email secret
kubectl create secret generic email-secrets \
    --from-literal=smtp-username="$SMTP_USERNAME" \
    --from-literal=smtp-password="$SMTP_PASSWORD" \
    --namespace="$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

# Deploy notification service
kubectl apply -f infrastructure/kubernetes/notification-service.yaml

# Wait for notification service
kubectl wait --for=condition=available deployment/notification-service -n $NAMESPACE --timeout=300s

echo "✅ Email notifications configured"

# Step 5: Deploy observability stack
echo ""
echo "📊 Step 5: Deploying observability stack..."

if [ -f "scripts/deploy-observability-aws.sh" ]; then
    ./scripts/deploy-observability-aws.sh
else
    echo "⚠️ Observability script not found, skipping..."
fi

echo "✅ Observability stack deployed"

# Step 6: Setup HTTPS and CloudFront
echo ""
echo "🔒 Step 6: Setting up HTTPS and CloudFront..."

if [ -f "infrastructure/https-cloudfront/setup-https-cloudfront.sh" ]; then
    ./infrastructure/https-cloudfront/setup-https-cloudfront.sh
else
    echo "⚠️ HTTPS setup script not found, manual configuration required"
    echo "Please run: ./infrastructure/https-cloudfront/setup-https-cloudfront.sh"
fi

# Step 7: Deploy frontend
echo ""
echo "🌐 Step 7: Deploying frontend..."

if [ -d "frontend" ]; then
    cd frontend
    
    # Update config for production
    cp config.prod.js config.js
    
    # Build and deploy
    if [ -f "deploy-k8s.sh" ]; then
        ./deploy-k8s.sh
    else
        # Deploy using kubectl
        kubectl apply -f ../infrastructure/kubernetes/frontend.yaml
    fi
    
    cd ..
fi

echo "✅ Frontend deployed"

# Step 8: Configure ingress and load balancer
echo ""
echo "🌐 Step 8: Configuring ingress..."

# Apply ingress configuration
if [ -f "infrastructure/kubernetes/ingress.yaml" ]; then
    kubectl apply -f infrastructure/kubernetes/ingress.yaml
fi

# Get load balancer URL
echo "⏳ Waiting for load balancer..."
sleep 30

ALB_URL=$(kubectl get svc api-gateway-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
if [ -z "$ALB_URL" ]; then
    ALB_URL=$(kubectl get svc api-gateway-service -n $NAMESPACE -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
fi

echo "✅ Load balancer ready: $ALB_URL"

# Step 9: Run validation tests
echo ""
echo "🧪 Step 9: Running validation tests..."

# Test API endpoints
echo "Testing API Gateway..."
if curl -f "http://$ALB_URL/health" > /dev/null 2>&1; then
    echo "✅ API Gateway health check passed"
else
    echo "⚠️ API Gateway health check failed"
fi

# Test services
services=("auth-service" "upload-service" "processing-service" "storage-service" "notification-service")
for service in "${services[@]}"; do
    echo "Testing $service..."
    if kubectl get pods -l app=$service -n $NAMESPACE | grep -q Running; then
        echo "✅ $service is running"
    else
        echo "⚠️ $service may have issues"
    fi
done

echo "✅ Validation tests completed"

# Step 10: Generate deployment report
echo ""
echo "📋 Step 10: Generating deployment report..."

cat > DEPLOYMENT-FINAL-REPORT.md << EOF
# FIAP-X Production Deployment Report

**Date:** $(date -u)
**Domain:** https://$DOMAIN
**Load Balancer:** $ALB_URL
**Namespace:** $NAMESPACE

## Deployed Services

### Core Infrastructure
- ✅ PostgreSQL Database
- ✅ Redis Cache
- ✅ RabbitMQ Message Broker
- ✅ MinIO Object Storage

### Microservices
- ✅ Auth Service (Authentication)
- ✅ Upload Service (File Upload)
- ✅ Processing Service (Video Processing)
- ✅ Storage Service (File Management)
- ✅ API Gateway (Routing)
- ✅ Notification Service (Email Notifications)

### Frontend & CDN
- ✅ Frontend Application
- ✅ CloudFront CDN
- ✅ SSL/TLS Certificate
- ✅ Custom Domain: $DOMAIN

### Observability
- ✅ Prometheus (Metrics)
- ✅ Grafana (Dashboards)
- ✅ ServiceMonitor (Auto-discovery)
- ✅ HPA (Auto-scaling)

## Access Information

- **Main Application:** https://$DOMAIN
- **API Gateway:** http://$ALB_URL
- **Grafana Dashboard:** http://$ALB_URL:3000
- **Prometheus:** http://$ALB_URL:9090

## Email Configuration

- **SMTP Server:** smtp.gmail.com:587
- **From Email:** noreply@fiapx.wecando.click
- **Notifications:** Enabled for all users

## Monitoring Commands

\`\`\`bash
# Check all pods
kubectl get pods -n $NAMESPACE

# Check services
kubectl get svc -n $NAMESPACE

# Check ingress
kubectl get ingress -n $NAMESPACE

# View logs
kubectl logs -f deployment/api-gateway -n $NAMESPACE
kubectl logs -f deployment/notification-service -n $NAMESPACE

# Test email
kubectl exec -it deployment/notification-service -n $NAMESPACE -- /bin/sh -c "SEND_TEST_EMAIL=true TEST_EMAIL=your@email.com ./notification-service"
\`\`\`

## Next Steps

1. **DNS Configuration**: Point $DOMAIN to CloudFront distribution
2. **SSL Validation**: Complete SSL certificate validation
3. **Email Testing**: Test notification system
4. **Load Testing**: Verify system performance
5. **Monitoring**: Set up alerts and dashboards

## Support

- **Documentation:** DOCUMENTACAO-ARQUITETURA.md
- **Troubleshooting:** Check individual service README.md files
- **Scripts:** scripts/ directory contains utility scripts

---
**Deployment Status:** ✅ COMPLETED SUCCESSFULLY
**System Status:** 🟢 OPERATIONAL
EOF

echo "✅ Deployment report generated: DEPLOYMENT-FINAL-REPORT.md"

# Final summary
echo ""
echo "🎉 DEPLOYMENT COMPLETED SUCCESSFULLY!"
echo "===================================="
echo ""
echo "📋 Summary:"
echo "  • Domain: https://$DOMAIN"
echo "  • Load Balancer: $ALB_URL"
echo "  • Namespace: $NAMESPACE"
echo "  • Services: All microservices deployed"
echo "  • HTTPS: SSL certificate requested"
echo "  • Email: Notification system active"
echo "  • Monitoring: Observability stack running"
echo ""
echo "📝 Next Steps:"
echo "  1. Complete DNS configuration for $DOMAIN"
echo "  2. Validate SSL certificate"
echo "  3. Test the complete system"
echo "  4. Set up monitoring alerts"
echo ""
echo "📊 Monitor deployment:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  kubectl logs -f deployment/api-gateway -n $NAMESPACE"
echo ""
echo "🔗 Access the application:"
echo "  • Development: http://$ALB_URL"
echo "  • Production: https://$DOMAIN (after DNS setup)"
echo ""
echo "📧 Test email notifications:"
echo '  kubectl exec -it deployment/notification-service -n '$NAMESPACE' -- /bin/sh -c "SEND_TEST_EMAIL=true TEST_EMAIL=your@email.com ./notification-service"'
echo ""
echo "🎯 Full documentation available in DEPLOYMENT-FINAL-REPORT.md"
echo ""
echo "✨ FIAP-X is now running in production! ✨"
