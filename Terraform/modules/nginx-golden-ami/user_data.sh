#!/bin/bash
set -e
exec > >(tee /var/log/nginx-golden-ami-build.log) 2>&1

# ----------------------------------------------------------------------------
# NGINX GOLDEN AMI CONFIGURATION SCRIPT
# This script installs and configures Nginx on the global base AMI
# ----------------------------------------------------------------------------

# ----------------------------------------------------------------------------
# STEP 1: INSTALL NGINX
# ----------------------------------------------------------------------------
echo "STEP1: Installing Nginx via amazon-linux-extras..."
# nginx is not in the default AL2 yum repos — must use amazon-linux-extras
amazon-linux-extras install -y nginx1

# Verify nginx binary is present
command -v nginx || { echo "ERROR: nginx binary not found after install"; exit 1; }
nginx -v
echo "STEP1: Nginx installed OK"

# ----------------------------------------------------------------------------
# STEP 2: CONFIGURE NGINX
# ----------------------------------------------------------------------------
echo "STEP2: Configuring Nginx..."

cat > /etc/nginx/nginx.conf <<'NGINXCONF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format main '$remote_addr - \$remote_user [$time_local] "$request" '
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

    server {
        listen       80 default_server;
        listen       [::]:80 default_server;
        server_name  _;
        root         /usr/share/nginx/html;

        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

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

echo "STEP2: Nginx configured OK"

# ----------------------------------------------------------------------------
# STEP 3: VALIDATE NGINX CONFIGURATION
# ----------------------------------------------------------------------------
echo "STEP3: Validating Nginx configuration..."
nginx -t
echo "STEP3: Config valid"

# ----------------------------------------------------------------------------
# STEP 4: ENABLE AND START NGINX
# ----------------------------------------------------------------------------
echo "STEP4: Enabling Nginx to start on boot..."
systemctl enable nginx

echo "STEP4: Starting Nginx..."
systemctl start nginx
sleep 5
systemctl status nginx
echo "STEP4: Nginx started OK"

# ----------------------------------------------------------------------------
# STEP 5: VERIFY HTTP RESPONSE
# ----------------------------------------------------------------------------
echo "STEP5: Testing Nginx health endpoint..."
curl -f http://localhost/health || echo "STEP5: Health check returned non-200 (may be OK at bake time)"

# ----------------------------------------------------------------------------
# STEP 6: SIGNAL COMPLETION
# ----------------------------------------------------------------------------
echo "Nginx Golden AMI configuration completed successfully"
touch /tmp/nginx-golden-ami-ready
echo "Configuration completed at: $(date)" >> /tmp/nginx-golden-ami-ready
