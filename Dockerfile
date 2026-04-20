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

WORKDIR /app

# Copy Gemfiles first for better caching
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Copy application code
COPY . .

# Precompile assets at build time so they are baked into the image.
# This makes first container start much faster and ensures assets exist
# even if the DB isn't ready at startup. Startup precompile in
# docker-compose.prod.yml is a fallback that runs after DB is healthy.
RUN SECRET_KEY_BASE=dummy DATABASE_URL=postgres://localhost/dummy RAILS_SERVE_STATIC_FILES=1 bundle exec rails assets:precompile

# Expose port
EXPOSE 3000

# Start the app
CMD ["bin/rails", "server", "-b", "0.0.0.0"]
