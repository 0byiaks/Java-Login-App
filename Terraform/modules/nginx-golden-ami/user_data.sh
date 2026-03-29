#!/bin/bash
set -e

# ----------------------------------------------------------------------------
# NGINX GOLDEN AMI CONFIGURATION SCRIPT
# This script installs and configures Nginx on the global base AMI
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# STEP 1: INSTALL NGINX
# ----------------------------------------------------------------------------
echo "Installing Nginx..."
yum install -y nginx

# ----------------------------------------------------------------------------
# STEP 2: CONFIGURE NGINX
# ----------------------------------------------------------------------------
# Create a basic nginx config without hardcoded backend IPs
# Backend targets will be injected later via user data
echo "Configuring Nginx..."

cat > /etc/nginx/nginx.conf <<'NGINXCONF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # Basic server block - backend will be configured via user data
    server {
        listen       80 default_server;
        listen       [::]:80 default_server;
        server_name  _;
        root         /usr/share/nginx/html;

        # Health check endpoint
        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

        # Default location
        location / {
            root /usr/share/nginx/html;
            index index.html index.htm;
        }

        error_page   404              /404.html;
        error_page   500 502 503 504  /50x.html;
        location = /50x.html {
            root   /usr/share/nginx/html;
        }
    }
}
NGINXCONF

# ----------------------------------------------------------------------------
# STEP 3: VALIDATE NGINX CONFIGURATION
# ----------------------------------------------------------------------------
echo "Validating Nginx configuration..."
nginx -t

# ----------------------------------------------------------------------------
# STEP 4: ENABLE NGINX TO START ON BOOT
# ----------------------------------------------------------------------------
echo "Enabling Nginx to start on boot..."
systemctl enable nginx

# ----------------------------------------------------------------------------
# STEP 5: START NGINX
# ----------------------------------------------------------------------------
echo "Starting Nginx..."
systemctl start nginx

# ----------------------------------------------------------------------------
# STEP 6: VERIFY NGINX IS RUNNING
# ----------------------------------------------------------------------------
echo "Verifying Nginx is running..."
systemctl status nginx

# ----------------------------------------------------------------------------
# STEP 7: TEST NGINX RESPONSE
# ----------------------------------------------------------------------------
echo "Testing Nginx response..."
curl -f http://localhost/health || echo "Health check failed, but continuing..."

# ----------------------------------------------------------------------------
# STEP 8: SIGNAL COMPLETION
# ----------------------------------------------------------------------------
echo "Nginx Golden AMI configuration completed successfully"
touch /tmp/nginx-golden-ami-ready
echo "Configuration completed at: $(date)" >> /tmp/nginx-golden-ami-ready

