# syntax = docker/dockerfile:1
FROM ruby:4.0-slim

# Install Node.js 20.x
RUN apt-get update && apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PostgreSQL client and other dependencies
RUN apt-get update && apt-get install -y \
    git \
    libyaml-dev \
    postgresql-client \
    libpq-dev \
    build-essential \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN adduser --system --home /app --shell /bin/bash --group --disabled-password appuser && \
    mkdir -p /app && chown -R appuser:appuser /app

WORKDIR /app

# Copy Gemfiles first for better caching
USER appuser
COPY --chown=appuser:appuser Gemfile Gemfile.lock ./
RUN bundle install

# Copy application code
COPY --chown=appuser:appuser . .

# Expose port
EXPOSE 3000

# Start the app
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
