# CI Test Dockerfile
# Mirrors GitHub Actions ubuntu-latest environment for local CI/CD testing
# Uses official Node.js Docker approach for better compatibility

FROM node:20.11.1

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHON_VERSION=3.11

# Install system dependencies (mirrors GitHub Actions ubuntu-latest)
RUN apt-get update && apt-get install -y \
    curl \
    wget \
    git \
    build-essential \
    ca-certificates \
    # PostgreSQL client tools (exact same as GitHub Actions setup)
    postgresql-client \
    # Python dependencies  
    python3 \
    python3-pip \
    python3-venv \
    # Other useful tools for debugging
    vim \
    less \
    && rm -rf /var/lib/apt/lists/*

# Verify installations (same as GitHub Actions)
RUN node --version && npm --version && psql --version && pg_isready --version

# Install pnpm (same as GitHub Actions)
RUN npm install -g pnpm@latest

# Verify pnpm installation
RUN pnpm --version

# Create working directory
WORKDIR /workspace

# Copy package files for dependency installation
COPY package*.json pnpm-*.yaml ./
COPY packages/ ./packages/
COPY playground/ ./playground/
COPY perdu/ ./perdu/

# Install dependencies (mirrors GitHub Actions setup steps)
RUN pnpm --filter=!playground install \
    && pnpm build \
    && pnpm install

# Install perdu dependencies
RUN cd perdu && npm install

# Make scripts executable (mirrors GitHub Actions setup)
RUN chmod +x perdu/scripts/*.sh

# Default command (will be overridden by docker-compose)
CMD ["bash"]