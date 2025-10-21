# Multi-stage Dockerfile for secure nginx deployment

# Stage 1: Build stage (prepare files)
FROM alpine:3.18 AS builder

# Install required tools
RUN apk add --no-cache \
    bash \
    coreutils

# Create app directory
WORKDIR /app

# Copy source files
COPY . .

# Create entrypoint script
RUN cat > docker-entrypoint.sh <<'EOF'
#!/bin/sh
# Replace placeholder in the shipped index.html with the runtime Formspree URL
if [ -n "$FORMSPREE_FORM_ID" ]; then
  sed -i "s|FORMSPREE_URL_PLACEHOLDER|https://formspree.io/f/$FORMSPREE_FORM_ID|g" /usr/share/nginx/html/index.html || true
else
  echo "Warning: FORMSPREE_FORM_ID not set"
fi
exec "$@"
EOF

# Make entrypoint executable
RUN chmod +x docker-entrypoint.sh

# Stage 2: Production stage  
FROM nginx:latest

# Create non-root user
RUN groupadd -g 1001 nginx-app && \
    useradd -r -u 1001 -g nginx-app -s /sbin/nologin nginx-app

# Update vulnerable packages
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y libxml2 libxslt1.1 libexpat1 xz-utils && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy static files from builder stage
COPY --from=builder /app/index.html /usr/share/nginx/html/
COPY --from=builder /app/docker-entrypoint.sh /docker-entrypoint.sh

# Copy custom nginx config for non-root user
RUN cat > /etc/nginx/nginx.conf <<'EOF'
worker_processes auto;
error_log /var/log/nginx/error.log notice;
pid /tmp/nginx.pid;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    
    sendfile on;
    tcp_nopush on;
    keepalive_timeout 65;
    
    # Temporary directories for non-root user
    client_body_temp_path /tmp/client_temp;
    proxy_temp_path /tmp/proxy_temp_path;
    fastcgi_temp_path /tmp/fastcgi_temp;
    uwsgi_temp_path /tmp/uwsgi_temp;
    scgi_temp_path /tmp/scgi_temp;
    
    server {
        listen 8080;
        server_name localhost;
        
        location / {
            root /usr/share/nginx/html;
            index index.html;
            try_files $uri $uri/ =404;
        }
        
        # Security headers
        add_header X-Content-Type-Options nosniff;
        add_header X-Frame-Options DENY;
        add_header X-XSS-Protection "1; mode=block";
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    }
}
EOF

# Create temp directories and set permissions
RUN mkdir -p /tmp/client_temp /tmp/proxy_temp_path /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp && \
    chown -R nginx-app:nginx-app /usr/share/nginx/html /tmp/client_temp /tmp/proxy_temp_path /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp /var/log/nginx && \
    chmod -R 755 /usr/share/nginx/html && \
    chmod +x /docker-entrypoint.sh

# Switch to non-root user
USER nginx-app

# Expose non-privileged port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/ || exit 1

# Use custom entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]