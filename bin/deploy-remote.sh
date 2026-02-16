#!/bin/bash
set -e

# Find the Lightsail key file
KEY_FILE=$(ls ~/.ssh/lightsail/LightsailDefaultKey-*.pem 2>/dev/null | head -n 1)

if [ -z "$KEY_FILE" ]; then
  echo "❌ Error: Lightsail key file not found in ~/.ssh/lightsail/"
  exit 1
fi

echo "🚀 Deploying to tourneyping.com..."

ssh -i "$KEY_FILE" ubuntu@44.226.63.157 << 'ENDSSH'
  set -e
  cd ~/schedule
  
  # Initialize rbenv
  export PATH="$HOME/.rbenv/bin:$PATH"
  eval "$(rbenv init -)"
  
  echo "📥 Pulling latest code..."
  # Stash any local changes (like certbot's nginx modifications)
  git stash
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
