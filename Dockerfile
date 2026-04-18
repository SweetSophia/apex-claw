# syntax = docker/dockerfile:1
FROM ruby:4.0-slim

# Install Node.js 20.x
RUN apt-get update && apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PostgreSQL client and other dependencies
RUN apt-get update && apt-get install -y \
    libyaml-dev \
    postgresql-client \
    libpq-dev \
    build-essential \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Gemfiles first for better caching
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy application code
COPY . .

# Expose port
EXPOSE 3000

# Start the app
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
