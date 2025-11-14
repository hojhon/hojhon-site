# Multi-stage Dockerfile for secure nginx deployment

# Stage 1: Build stage (prepare files)
FROM alpine:3.18 AS builder

# Accept build argument for Formspree Form ID
ARG FORMSPREE_FORM_ID

# Install required tools
RUN apk add --no-cache \
    bash \
    coreutils

# Create app directory
WORKDIR /app

# Copy source files
COPY . .

# Replace placeholder with actual Formspree URL during build
RUN if [ -n "$FORMSPREE_FORM_ID" ]; then \
      sed -i "s|FORMSPREE_URL_PLACEHOLDER|https://formspree.io/f/$FORMSPREE_FORM_ID|g" index.html; \
    else \
      echo "Warning: FORMSPREE_FORM_ID build arg not provided"; \
    fi

# Stage 2: Production stage
FROM nginx:alpine3.20

# Update packages to get security fixes, especially pcre2
RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache pcre2>=10.46-r0

# Create non-root user
RUN addgroup -g 1001 -S nginx-app && \
    adduser -S -D -H -u 1001 -h /var/cache/nginx -s /sbin/nologin -G nginx-app -g nginx-app nginx-app

# Copy static files from builder stage
COPY --from=builder /app/index.html /usr/share/nginx/html/
COPY --from=builder /app/blog/ /usr/share/nginx/html/blog/
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