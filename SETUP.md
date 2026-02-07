# Create a local .env file
cp .env.example .env

# IMPORTANT: Edit .env and add your actual credentials:
# - OPENAI_API_KEY: Get from https://platform.openai.com/api-keys
# - SMTP credentials: Get from SendGrid or Mailgun

# Install dependencies
bundle install
npm install

# Note: PostgreSQL is not running. You have two options:

# Option 1: Use Docker Compose (Recommended)
# This will start PostgreSQL and Redis automatically
docker-compose up -d db redis

# Option 2: Start PostgreSQL manually
# macOS: brew services start postgresql
# Linux: sudo systemctl start postgresql

# Then create and migrate the database
rails db:create
rails db:migrate

# Start the application
bin/dev
# OR manually start each service:
# rails server (in one terminal)
# bundle exec sidekiq (in another terminal)
