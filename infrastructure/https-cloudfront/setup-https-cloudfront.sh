#!/bin/bash

# FIAP-X HTTPS Setup Script
# Configures CloudFront, SSL Certificate, and Domain for fiapx.wecando.click

set -e

echo "🚀 FIAP-X HTTPS + CloudFront Setup"
echo "=================================="

# Configuration
DOMAIN="fiapx.wecando.click"
WILDCARD_DOMAIN="*.fiapx.wecando.click"
REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Get ALB DNS name from Kubernetes
echo "📡 Getting ALB DNS name..."
ALB_DNS=$(kubectl get svc api-gateway-service -n fiapx -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$ALB_DNS" ]; then
    echo "❌ Error: Could not get ALB DNS name. Make sure api-gateway-service is running."
    exit 1
fi

echo "✅ ALB DNS: $ALB_DNS"

# Step 1: Request SSL Certificate
echo "🔐 Step 1: Requesting SSL Certificate..."

CERT_ARN=$(aws acm request-certificate \
    --domain-name "$DOMAIN" \
    --subject-alternative-names "$WILDCARD_DOMAIN" \
    --validation-method DNS \
    --region "$REGION" \
    --tags Key=Name,Value="FIAP-X SSL Certificate" Key=Environment,Value=production Key=Project,Value=fiapx \
    --query CertificateArn --output text)

echo "✅ Certificate requested: $CERT_ARN"

# Step 2: Get DNS validation records
echo "📋 Step 2: Getting DNS validation records..."

sleep 10  # Wait for certificate to be processed

aws acm describe-certificate \
    --certificate-arn "$CERT_ARN" \
    --region "$REGION" \
    --query 'Certificate.DomainValidationOptions[*].[DomainName,ResourceRecord.Name,ResourceRecord.Type,ResourceRecord.Value]' \
    --output table

echo ""
echo "⚠️  IMPORTANT: Add the above DNS records to your domain registrar:"
echo "   - Domain: wecando.click"
echo "   - Add CNAME records as shown above"
echo ""
read -p "Press Enter after adding DNS records to continue..."

# Step 3: Wait for certificate validation
echo "⏳ Step 3: Waiting for certificate validation..."

echo "Checking certificate status..."
while true; do
    STATUS=$(aws acm describe-certificate \
        --certificate-arn "$CERT_ARN" \
        --region "$REGION" \
        --query 'Certificate.Status' --output text)
    
    echo "Certificate status: $STATUS"
    
    if [ "$STATUS" = "ISSUED" ]; then
        echo "✅ Certificate validated successfully!"
        break
    elif [ "$STATUS" = "FAILED" ]; then
        echo "❌ Certificate validation failed!"
        exit 1
    fi
    
    echo "Still waiting... (checking again in 30 seconds)"
    sleep 30
done

# Step 4: Create CloudFront distribution
echo "☁️ Step 4: Creating CloudFront distribution..."

# Create distribution config
cat > /tmp/distribution-config.json << EOF
{
  "CallerReference": "fiapx-$(date +%s)",
  "Comment": "FIAP-X Video Processing Platform - Production",
  "DefaultCacheBehavior": {
    "TargetOriginId": "fiapx-alb-origin",
    "ViewerProtocolPolicy": "redirect-to-https",
    "TrustedSigners": {
      "Enabled": false,
      "Quantity": 0
    },
    "ForwardedValues": {
      "QueryString": true,
      "Cookies": {
        "Forward": "all"
      },
      "Headers": {
        "Quantity": 8,
        "Items": [
          "Authorization",
          "Content-Type",
          "Origin",
          "Accept",
          "User-Agent",
          "X-Forwarded-For",
          "Host",
          "X-Forwarded-Proto"
        ]
      }
    },
    "MinTTL": 0,
    "DefaultTTL": 0,
    "MaxTTL": 86400,
    "Compress": true
  },
  "CacheBehaviors": {
    "Quantity": 3,
    "Items": [
      {
        "PathPattern": "/api/*",
        "TargetOriginId": "fiapx-alb-origin",
        "ViewerProtocolPolicy": "redirect-to-https",
        "TrustedSigners": {
          "Enabled": false,
          "Quantity": 0
        },
        "ForwardedValues": {
          "QueryString": true,
          "Cookies": {
            "Forward": "all"
          },
          "Headers": {
            "Quantity": 1,
            "Items": ["*"]
          }
        },
        "MinTTL": 0,
        "DefaultTTL": 0,
        "MaxTTL": 0,
        "Compress": true
      },
      {
        "PathPattern": "/upload/*",
        "TargetOriginId": "fiapx-alb-origin",
        "ViewerProtocolPolicy": "redirect-to-https",
        "TrustedSigners": {
          "Enabled": false,
          "Quantity": 0
        },
        "ForwardedValues": {
          "QueryString": true,
          "Cookies": {
            "Forward": "all"
          },
          "Headers": {
            "Quantity": 1,
            "Items": ["*"]
          }
        },
        "MinTTL": 0,
        "DefaultTTL": 0,
        "MaxTTL": 0,
        "Compress": false
      },
      {
        "PathPattern": "/download/*",
        "TargetOriginId": "fiapx-alb-origin",
        "ViewerProtocolPolicy": "redirect-to-https",
        "TrustedSigners": {
          "Enabled": false,
          "Quantity": 0
        },
        "ForwardedValues": {
          "QueryString": true,
          "Cookies": {
            "Forward": "all"
          },
          "Headers": {
            "Quantity": 1,
            "Items": ["*"]
          }
        },
        "MinTTL": 0,
        "DefaultTTL": 86400,
        "MaxTTL": 31536000,
        "Compress": true
      }
    ]
  },
  "Origins": {
    "Quantity": 1,
    "Items": [
      {
        "Id": "fiapx-alb-origin",
        "DomainName": "$ALB_DNS",
        "CustomOriginConfig": {
          "HTTPPort": 80,
          "HTTPSPort": 443,
          "OriginProtocolPolicy": "http-only",
          "OriginSslProtocols": {
            "Quantity": 1,
            "Items": ["TLSv1.2"]
          }
        }
      }
    ]
  },
  "Aliases": {
    "Quantity": 2,
    "Items": ["$DOMAIN", "www.$DOMAIN"]
  },
  "ViewerCertificate": {
    "ACMCertificateArn": "$CERT_ARN",
    "SSLSupportMethod": "sni-only",
    "MinimumProtocolVersion": "TLSv1.2_2021"
  },
  "Enabled": true,
  "PriceClass": "PriceClass_100",
  "HttpVersion": "http2",
  "IsIPV6Enabled": true,
  "WebACLId": "",
  "DefaultRootObject": "index.html"
}
EOF

# Create CloudFront distribution
DISTRIBUTION_ID=$(aws cloudfront create-distribution \
    --distribution-config file:///tmp/distribution-config.json \
    --query 'Distribution.Id' --output text)

echo "✅ CloudFront distribution created: $DISTRIBUTION_ID"

# Get CloudFront domain name
CLOUDFRONT_DOMAIN=$(aws cloudfront get-distribution \
    --id "$DISTRIBUTION_ID" \
    --query 'Distribution.DomainName' --output text)

echo "✅ CloudFront domain: $CLOUDFRONT_DOMAIN"

# Step 5: Configure DNS
echo "🌐 Step 5: DNS Configuration Required"
echo ""
echo "Add the following DNS records to your domain registrar (wecando.click):"
echo ""
echo "CNAME Records:"
echo "  fiapx.wecando.click     → $CLOUDFRONT_DOMAIN"
echo "  www.fiapx.wecando.click → $CLOUDFRONT_DOMAIN"
echo ""

# Step 6: Wait for distribution deployment
echo "⏳ Step 6: Waiting for CloudFront distribution deployment..."

while true; do
    STATUS=$(aws cloudfront get-distribution \
        --id "$DISTRIBUTION_ID" \
        --query 'Distribution.Status' --output text)
    
    echo "Distribution status: $STATUS"
    
    if [ "$STATUS" = "Deployed" ]; then
        echo "✅ Distribution deployed successfully!"
        break
    fi
    
    echo "Still deploying... (checking again in 60 seconds)"
    sleep 60
done

# Step 7: Update frontend configuration
echo "🔧 Step 7: Updating frontend configuration..."

# Update frontend config for production
cat > infrastructure/https-cloudfront/frontend-config-https.js << EOF
// HTTPS Production Configuration
const API_CONFIG = {
    BASE_URL: 'https://$DOMAIN',
    API_GATEWAY_URL: 'https://$DOMAIN/api',
    AUTH_SERVICE_URL: 'https://$DOMAIN/auth',
    UPLOAD_SERVICE_URL: 'https://$DOMAIN/upload',
    PROCESSING_SERVICE_URL: 'https://$DOMAIN/processing',
    STORAGE_SERVICE_URL: 'https://$DOMAIN/storage',
    WEBSOCKET_URL: 'wss://$DOMAIN/ws',
    
    // CloudFront specific
    CDN_URL: 'https://$CLOUDFRONT_DOMAIN',
    STATIC_ASSETS_URL: 'https://$CLOUDFRONT_DOMAIN/assets',
    
    // Features
    HTTPS_ENABLED: true,
    CDN_ENABLED: true,
    SSL_CERTIFICATE: '$CERT_ARN'
};

// Export for use in application
if (typeof module !== 'undefined' && module.exports) {
    module.exports = API_CONFIG;
} else {
    window.API_CONFIG = API_CONFIG;
}
EOF

# Step 8: Create HTTPS validation script
echo "🧪 Step 8: Creating HTTPS validation script..."

cat > infrastructure/https-cloudfront/validate-https.sh << 'EOF'
#!/bin/bash

echo "🔒 HTTPS Validation for FIAP-X"
echo "=============================="

DOMAIN="fiapx.wecando.click"

# Test HTTPS connectivity
echo "1. Testing HTTPS connectivity..."
if curl -I "https://$DOMAIN" --max-time 10 > /dev/null 2>&1; then
    echo "✅ HTTPS is working!"
else
    echo "❌ HTTPS connection failed"
    exit 1
fi

# Test SSL certificate
echo "2. Testing SSL certificate..."
SSL_INFO=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN":443 2>/dev/null | openssl x509 -noout -dates -subject)
echo "$SSL_INFO"

# Test API endpoints
echo "3. Testing API endpoints..."
echo "Testing /health endpoint..."
if curl -s "https://$DOMAIN/api/health" > /dev/null; then
    echo "✅ API Gateway accessible"
else
    echo "❌ API Gateway not accessible"
fi

# Test CloudFront headers
echo "4. Testing CloudFront headers..."
HEADERS=$(curl -I "https://$DOMAIN" 2>/dev/null | grep -i cloudfront)
if [ ! -z "$HEADERS" ]; then
    echo "✅ CloudFront is working!"
    echo "$HEADERS"
else
    echo "⚠️  CloudFront headers not detected"
fi

echo ""
echo "🎉 HTTPS Setup Complete!"
echo "Site accessible at: https://$DOMAIN"
EOF

chmod +x infrastructure/https-cloudfront/validate-https.sh

# Step 9: Save configuration
echo "💾 Step 9: Saving configuration..."

cat > infrastructure/https-cloudfront/https-config.env << EOF
# HTTPS Configuration for FIAP-X
DOMAIN=$DOMAIN
WILDCARD_DOMAIN=$WILDCARD_DOMAIN
CERTIFICATE_ARN=$CERT_ARN
DISTRIBUTION_ID=$DISTRIBUTION_ID
CLOUDFRONT_DOMAIN=$CLOUDFRONT_DOMAIN
ALB_DNS=$ALB_DNS
REGION=$REGION
ACCOUNT_ID=$ACCOUNT_ID
SETUP_DATE=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
EOF

echo ""
echo "🎉 HTTPS + CloudFront Setup Complete!"
echo "===================================="
echo ""
echo "📋 Summary:"
echo "  • Domain: https://$DOMAIN"
echo "  • Certificate: $CERT_ARN"
echo "  • CloudFront: $DISTRIBUTION_ID"
echo "  • CDN Domain: $CLOUDFRONT_DOMAIN"
echo ""
echo "📝 Next Steps:"
echo "  1. Add DNS records as shown above"
echo "  2. Test HTTPS: ./infrastructure/https-cloudfront/validate-https.sh"
echo "  3. Update frontend config to use HTTPS URLs"
echo ""
echo "Configuration saved in: infrastructure/https-cloudfront/https-config.env"

# Clean up temp files
rm -f /tmp/distribution-config.json
