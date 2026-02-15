# Deployment Guide for Tourneyping.com

## Prerequisites

- AWS Lightsail account
- Domain: tourneyping.com (configured)
- SendGrid verified domain

## Deployment Steps

### 1. Create Lightsail Instance

1. Log into AWS Lightsail console
2. Create instance:
   - Platform: Linux/Unix
   - Blueprint: Ubuntu 22.04 LTS
   - Plan: $10/month (2GB RAM, 1 vCPU, 60GB SSD)
   - Name: tourneyping-production
3. Wait for instance to start
4. Create static IP and attach to instance
5. Update DNS A record to point to static IP

### 2. Initial Server Setup

SSH into your Lightsail instance:
```bash
ssh ubuntu@YOUR_STATIC_IP
```

Download and run the setup script from repository:
```bash
curl -O https://raw.githubusercontent.com/yang70/schedule-alert/main/bin/lightsail-setup.sh
chmod +x lightsail-setup.sh
./lightsail-setup.sh
```

### 3. Deploy Application

Clone the repository:
```bash
cd ~/schedule
git clone https://github.com/yang70/schedule-alert.git .
```

Create `.env.production` file:
```bash
nano .env.production
```

Add your environment variables:
```
RAILS_ENV=production
SECRET_KEY_BASE=<run: bundle exec rails secret>
DATABASE_URL=postgresql://ubuntu:PASSWORD@localhost/schedule_production
REDIS_URL=redis://localhost:6379/0
OPENAI_API_KEY=your_openai_key
SMTP_ADDRESS=smtp.sendgrid.net
SMTP_PORT=587
SMTP_DOMAIN=tourneyping.com
SMTP_USERNAME=apikey
SMTP_PASSWORD=your_sendgrid_api_key
FROM_EMAIL=noreply@tourneyping.com
APP_HOST=tourneyping.com
RAILS_MASTER_KEY=<from config/master.key>
```

Install dependencies and setup database:
```bash
bundle install --without development test --deployment
npm install
RAILS_ENV=production bundle exec rails db:create db:migrate
RAILS_ENV=production bundle exec rails assets:precompile
```

### 4. Install Services

Copy systemd service files:
```bash
sudo cp config/systemd/*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable tourneyping-web tourneyping-worker
sudo systemctl start tourneyping-web tourneyping-worker
```

### 5. Configure Nginx

Copy nginx configuration:
```bash
sudo cp config/nginx/tourneyping.conf /etc/nginx/sites-available/
sudo ln -s /etc/nginx/sites-available/tourneyping.conf /etc/nginx/sites-enabled/
sudo rm /etc/nginx/sites-enabled/default  # Remove default site
```

### 6. Setup SSL Certificate

Install Let's Encrypt certificate:
```bash
sudo certbot --nginx -d tourneyping.com -d www.tourneyping.com
```

Test nginx configuration and reload:
```bash
sudo nginx -t
sudo systemctl reload nginx
```

### 7. Verify Deployment

Check services are running:
```bash
sudo systemctl status tourneyping-web
sudo systemctl status tourneyping-worker
sudo systemctl status nginx
```

Visit https://tourneyping.com to verify!

## Future Deployments

After initial setup, deploying updates is simple:

```bash
ssh ubuntu@YOUR_STATIC_IP
cd ~/schedule
./bin/deploy.sh
```

Or add an SSH key to GitHub and run remotely:
```bash
ssh ubuntu@YOUR_STATIC_IP 'cd ~/schedule && ./bin/deploy.sh'
```

## Monitoring

View logs:
```bash
# Web server logs
sudo journalctl -u tourneyping-web -f

# Worker logs
sudo journalctl -u tourneyping-worker -f

# Nginx logs
sudo tail -f /var/log/nginx/tourneyping_access.log
sudo tail -f /var/log/nginx/tourneyping_error.log
```

## Backup

Setup automatic PostgreSQL backups:
```bash
# Add to crontab
crontab -e

# Daily backup at 2 AM
0 2 * * * pg_dump schedule_production > /home/ubuntu/backups/db_$(date +\%Y\%m\%d).sql
```

## Troubleshooting

If services won't start:
1. Check logs: `sudo journalctl -u tourneyping-web -n 50`
2. Verify .env.production has all required variables
3. Check database connection
4. Ensure secret key is set

If assets aren't loading:
1. Run: `RAILS_ENV=production bundle exec rails assets:precompile`
2. Check nginx config
3. Restart nginx: `sudo systemctl restart nginx`
