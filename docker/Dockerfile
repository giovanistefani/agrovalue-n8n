FROM n8nio/n8n:latest

# Install additional packages if needed
USER root
RUN apk add --no-cache \
    python3 \
    py3-pip \
    curl \
    jq \
    git \
    openssh-client

# Install Python packages for custom nodes
RUN pip3 install --no-cache-dir \
    requests \
    pandas \
    numpy \
    boto3 \
    psycopg2-binary

# Custom nodes directory
COPY custom-nodes/ /home/node/.n8n/custom/

# Switch back to node user
USER node

# Copy custom configurations
COPY --chown=node:node configs/production/ /home/node/.n8n/config/

# Set working directory
WORKDIR /home/node/.n8n

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD curl -f http://localhost:5678/healthz || exit 1

# Expose port
EXPOSE 5678

# Start n8n
CMD ["n8n"]
