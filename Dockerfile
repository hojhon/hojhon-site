FROM nginx:alpine

# Copy the static files to nginx html directory
COPY . /usr/share/nginx/html/

# Create a script to replace the Formspree URL at runtime
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

# Expose port 80
EXPOSE 80

# Use our custom entrypoint
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]