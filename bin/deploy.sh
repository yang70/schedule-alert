#!/bin/bash
set -e

echo "🚀 Deploying tourneyping.com..."

# Navigate to app directory
cd /home/ubuntu/schedule

# Pull latest code
echo "📥 Pulling latest code from git..."
git pull origin main

# Install dependencies
echo "📦 Installing Ruby gems..."
bundle install --without development test --deployment

echo "📦 Installing Node packages..."
npm install

# Precompile assets
echo "🎨 Precompiling assets..."
RAILS_ENV=production bundle exec rails assets:precompile

# Run database migrations
echo "🗄️  Running database migrations..."
RAILS_ENV=production bundle exec rails db:migrate

# Restart services
echo "🔄 Restarting services..."
sudo systemctl restart tourneyping-web
sudo systemctl restart tourneyping-worker

echo "✅ Deployment complete!"
echo "🌐 Visit https://tourneyping.com to see the changes"

# Show service status
echo ""
echo "📊 Service Status:"
sudo systemctl status tourneyping-web --no-pager -l | head -10
sudo systemctl status tourneyping-worker --no-pager -l | head -10
