#!/bin/bash
set -e

echo "🚀 Deploying to tourneyping.com..."

ssh ubuntu@44.226.63.157 << 'ENDSSH'
  cd ~/schedule
  echo "📥 Pulling latest code..."
  git pull

  echo "📦 Installing dependencies..."
  bundle install --without development test
  npm install

  echo "🎨 Precompiling assets..."
  RAILS_ENV=production bundle exec rails assets:precompile

  echo "🗄️  Running migrations..."
  RAILS_ENV=production bundle exec rails db:migrate

  echo "♻️  Restarting services..."
  sudo systemctl restart tourneyping-web tourneyping-worker

  echo "✅ Deployment complete!"
ENDSSH

echo "🎉 Successfully deployed to https://tourneyping.com"
