#!/bin/bash
#
# Lightsail Server Setup Script for Tourneyping
# Run this on a fresh Ubuntu 22.04 Lightsail instance
#
set -e

echo "🚀 Setting up Tourneyping on Lightsail..."

# Update system
echo "📦 Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install dependencies
echo "📦 Installing dependencies..."
sudo apt-get install -y \
  git curl libssl-dev libreadline-dev zlib1g-dev \
  autoconf bison build-essential libyaml-dev \
  libreadline-dev libncurses5-dev libffi-dev libgdbm-dev \
  nginx postgresql postgresql-contrib redis-server \
  certbot python3-certbot-nginx

# Install rbenv
echo "💎 Installing rbenv..."
if [ ! -d "$HOME/.rbenv" ]; then
  git clone https://github.com/rbenv/rbenv.git ~/.rbenv
  echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
  echo 'eval "$(rbenv init -)"' >> ~/.bashrc
  git clone https://github.com/rbenv/ruby-build.git ~/.rbenv/plugins/ruby-build
fi

export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"

# Install Ruby 3.3.10
echo "💎 Installing Ruby 3.3.10..."
rbenv install 3.3.10 || true
rbenv global 3.3.10

# Install Bundler
echo "💎 Installing Bundler..."
gem install bundler

# Install Node.js
echo "📦 Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Configure PostgreSQL
echo "🗄️  Configuring PostgreSQL..."
sudo -u postgres createuser -s ubuntu || true
sudo -u postgres createdb schedule_production || true

# Configure PostgreSQL password
echo "Please enter a password for the PostgreSQL database:"
read -s DB_PASSWORD
sudo -u postgres psql -c "ALTER USER ubuntu WITH PASSWORD '$DB_PASSWORD';"

# Start services
echo "🔄 Starting services..."
sudo systemctl enable redis-server
sudo systemctl start redis-server
sudo systemctl enable postgresql
sudo systemctl start postgresql

# Create app directory
echo "📁 Creating app directory..."
mkdir -p ~/schedule

echo "✅ Server setup complete!"
echo ""
echo "Next steps:"
echo "1. Clone your repository: cd ~/schedule && git clone https://github.com/yang70/schedule-alert.git ."
echo "2. Create .env.production file with your environment variables"
echo "3. Run bundle install and setup database"
echo "4. Install systemd services and nginx config"
echo ""
echo "Database password: (save this!)"
echo "DATABASE_URL=postgresql://ubuntu:$DB_PASSWORD@localhost/schedule_production"
