#!/bin/bash
set -e
exec > >(tee /var/log/nginx-asg-userdata.log) 2>&1

PRIVATE_NLB_DNS_NAME="${private_nlb_dns_name}"

echo "Configuring Nginx reverse proxy to private NLB: $PRIVATE_NLB_DNS_NAME"

cat > /etc/nginx/nginx.conf <<EOF
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

events {
    worker_connections 1024;
}

http {
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    upstream tomcat_backend {
        server $${PRIVATE_NLB_DNS_NAME}:8080;
    }

    server {
        listen       80 default_server;
        listen       [::]:80 default_server;
        server_name  _;

        location /health {
            access_log off;
            return 200 "healthy\n";
            add_header Content-Type text/plain;
        }

        location / {
            proxy_pass http://tomcat_backend;
            proxy_http_version 1.1;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF

nginx -t
systemctl enable nginx
systemctl restart nginx

echo "Waiting for Nginx HTTP on port 80 (up to ~2 minutes)..."
ok=0
for i in $(seq 1 60); do
  if curl -s -o /dev/null --connect-timeout 2 http://127.0.0.1/health; then
    echo "Nginx is responding on port 80 (attempt $i)"
    ok=1
    break
  fi
  echo "  ... waiting ($i/60)"
  sleep 2
done

if [ "$ok" -ne 1 ]; then
  echo "ERROR: Timed out waiting for Nginx on port 80"
  systemctl status nginx || true
  exit 1
fi

echo "SUCCESS: Nginx configured and proxying to private NLB."
