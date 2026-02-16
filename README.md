# TourneyPing

A web application that monitors sports tournament schedule URLs and notifies users when schedules become available or change. Uses AI (OpenAI/ChatGPT) to intelligently detect and summarize schedule changes.

## Features

- 🔐 **User Authentication** - Secure email/password login with Devise
- 🔗 **URL Monitoring** - Track multiple tournament schedule URLs
- 🤖 **AI-Powered Analysis** - Uses OpenAI to detect schedule availability and changes
- 📧 **Email Notifications** - Get notified when schedules appear or change
- ⚡ **Background Processing** - Sidekiq workers check URLs every 15 minutes
- 💾 **Change History** - Track all schedule changes over time
- 🎨 **Modern UI** - Vue.js frontend with Bootstrap styling

## Technology Stack

### Backend
- Ruby 3.3.10
- Rails 8.1.2
- PostgreSQL (database)
- Redis (caching & background jobs)
- Sidekiq (async job processing)
- Devise (authentication)

### Frontend
- Vue.js 3
- Bootstrap 5
- Turbo & Stimulus (Hotwire)
- ESBuild (asset bundling)

### Integrations
- OpenAI API (GPT-4o-mini) for schedule analysis
- SendGrid/Mailgun for email delivery
- HTTParty for HTTP requests

### Infrastructure
- Docker & Docker Compose
- AWS deployment ready (ECS, EC2, RDS, ElastiCache)
- Kamal for deployment automation

## Prerequisites

- Ruby 3.3.10 (via rbenv or rvm)
- PostgreSQL 14+
- Redis 7+
- Node.js 18+ and npm
- OpenAI API key
- SMTP credentials (SendGrid or Mailgun)

## Installation

### 1. Clone the Repository
```bash
git clone <repository-url>
cd schedule
```

### 2. Install Dependencies
```bash
# Install Ruby gems
bundle install

# Install JavaScript packages
npm install
```

### 3. Set Up Environment Variables
```bash
# Copy the example file
cp .env.example .env

# Edit .env and add your credentials
# - OpenAI API key
# - SMTP credentials
# - Database URL (if not using default)
```

### 4. Set Up Database
```bash
# Create and migrate database
rails db:create
rails db:migrate
```

### 5. Start Services

#### Option A: Using Docker Compose (Recommended)
```bash
# Start PostgreSQL and Redis
docker-compose up -d db redis

# Run migrations
rails db:migrate

# Start Rails server
bin/dev
```

#### Option B: Manual Setup
```bash
# Make sure PostgreSQL and Redis are running locally

# In terminal 1: Start Rails server
rails server

# In terminal 2: Start Sidekiq
bundle exec sidekiq

# In terminal 3: Start asset compilation (optional for development)
npm run build
```

### 6. Access the Application
Open your browser and visit:
- **Application:** http://localhost:3000
- **Sidekiq Dashboard:** http://localhost:3000/sidekiq (development only)

## Usage

### 1. Create an Account
- Navigate to http://localhost:3000
- Click "Sign up" and create an account

### 2. Add URLs to Monitor
- Once logged in, you'll see the dashboard
- Fill in the form with:
  - **Name:** A descriptive name for the schedule (e.g., "Spring Soccer Tournament 2026")
  - **URL:** The web page URL to monitor
  - **Notification Email:** (Optional) Override email for notifications

### 3. How It Works
1. **Initial Check:** When you add a URL, the system immediately checks it
2. **AI Analysis:** OpenAI analyzes the page to determine if a schedule is present
3. **Regular Monitoring:** Sidekiq checks all active URLs every 15 minutes
4. **Change Detection:** When changes are detected, AI summarizes what changed
5. **Notifications:** Email alerts are sent for:
   - Schedule becomes available (first time)
   - Schedule changes (subsequent updates)

### 4. Managing URLs
- **Check Now:** Manually trigger an immediate check
- **Remove:** Stop monitoring a URL
- **View History:** See all detected changes with AI summaries

## Configuration

### Email Settings
Edit `.env` to configure your email provider:

**SendGrid:**
```bash
SMTP_ADDRESS=smtp.sendgrid.net
SMTP_PORT=587
SMTP_USERNAME=apikey
SMTP_PASSWORD=your_sendgrid_api_key
```

**Mailgun:**
```bash
SMTP_ADDRESS=smtp.mailgun.org
SMTP_PORT=587
SMTP_USERNAME=postmaster@mg.yourdomain.com
SMTP_PASSWORD=your_mailgun_smtp_password
```

### OpenAI Configuration
```bash
OPENAI_API_KEY=sk-...your-key-here
```

### Monitoring Frequency
Edit `config/sidekiq.yml` to change check frequency:
```yaml
:schedule:
  check_all_urls:
    cron: '*/15 * * * *'  # Every 15 minutes (default)
```

## Deployment

### AWS Deployment
See [AWS_DEPLOYMENT.md](AWS_DEPLOYMENT.md) for detailed instructions on deploying to:
- AWS ECS (Fargate)
- AWS EC2
- AWS Elastic Beanstalk

### Quick Docker Deployment
```bash
# Build and run with Docker Compose
docker-compose -f docker-compose.production.yml up -d

# Run migrations
docker-compose -f docker-compose.production.yml run web rails db:migrate
```

## Production Management

### Production Console Access

When deployed to a server (without Docker), use these helper scripts to run Rails commands with the proper environment variables loaded:

```bash
# Interactive Rails console
./bin/production-console

# Run one-off commands
./bin/production-runner "MonitoredUrl.count"
./bin/production-runner "puts MonitoredUrl.due_for_check.map(&:name)"
```

These scripts automatically load environment variables from `.env.production` and set `RAILS_ENV=production`.

### Monitoring Background Jobs

```bash
# View worker logs
sudo journalctl -u tourneyping-worker.service -f

# Check worker status
sudo systemctl status tourneyping-worker.service

# Restart worker
sudo systemctl restart tourneyping-worker.service
```

### Viewing Application Logs

```bash
# View web server logs
sudo journalctl -u tourneyping-web.service -f

# View both services
sudo journalctl -u tourneyping-web.service -u tourneyping-worker.service -f
```

## Development

### Running Tests
```bash
# Run all tests (when test suite is set up)
rails test
```

### Console Access
```bash
# Rails console
rails console

# Check monitored URLs
MonitoredUrl.all

# Manually trigger a check
UrlCheckJob.perform_now(monitored_url_id)
```

### Database Console
```bash
rails dbconsole
```

## Project Structure

```
schedule/
├── app/
│   ├── controllers/         # Rails controllers
│   │   ├── dashboard_controller.rb
│   │   └── monitored_urls_controller.rb
│   ├── jobs/                # Sidekiq background jobs
│   │   ├── url_check_job.rb
│   │   └── check_all_urls_job.rb
│   ├── mailers/             # Email mailers
│   │   └── notification_mailer.rb
│   ├── models/              # ActiveRecord models
│   │   ├── user.rb
│   │   ├── monitored_url.rb
│   │   └── schedule_snapshot.rb
│   ├── services/            # Business logic services
│   │   └── open_ai_service.rb
│   ├── javascript/          # Vue.js frontend
│   │   ├── application.js
│   │   └── components/
│   │       └── Dashboard.js
│   └── views/               # ERB templates
├── config/
│   ├── database.yml         # Database configuration
│   ├── sidekiq.yml          # Sidekiq configuration
│   └── routes.rb            # Application routes
├── db/
│   └── migrate/             # Database migrations
├── docker-compose.yml       # Docker setup
├── Dockerfile               # Docker image definition
├── .env.example             # Environment variables template
└── README.md                # This file
```

## Key Models

### User
- Authenticated via Devise
- Has many MonitoredUrls

### MonitoredUrl
- Belongs to User
- Tracks URL, name, active status
- Has many ScheduleSnapshots

### ScheduleSnapshot
- Belongs to MonitoredUrl
- Stores historical content and AI analysis
- Tracks changes over time

## Background Jobs

### UrlCheckJob
- Checks a single URL
- Fetches content via HTTParty
- Analyzes with OpenAI
- Creates snapshot
- Sends notifications if needed

### CheckAllUrlsJob
- Runs every 15 minutes (configurable)
- Queues UrlCheckJob for all active URLs

## Troubleshooting

### PostgreSQL Connection Issues
```bash
# Check if PostgreSQL is running
ps aux | grep postgres

# Start PostgreSQL
# macOS:
brew services start postgresql

# Linux:
sudo systemctl start postgresql
```

### Redis Connection Issues
```bash
# Check if Redis is running
redis-cli ping

# Start Redis
# macOS:
brew services start redis

# Linux:
sudo systemctl start redis
```

### Sidekiq Not Processing Jobs
```bash
# Check Sidekiq process
ps aux | grep sidekiq

# Restart Sidekiq
bundle exec sidekiq -C config/sidekiq.yml
```

### OpenAI API Errors
- Verify your API key is correct in `.env`
- Check your OpenAI account has credits
- Review rate limits in OpenAI dashboard

## Future Enhancements

- [ ] SMS notifications via Twilio
- [ ] Mobile app (React Native)
- [ ] Webhook notifications
- [ ] Custom check frequencies per URL
- [ ] Schedule comparison view
- [ ] Multi-language support
- [ ] API for external integrations
- [ ] Schedule export (PDF, iCal)

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License.

## Support

For issues and questions:
- Open an issue on GitHub
- Check existing documentation
- Review error logs in `log/` directory

## Acknowledgments

- Built with Ruby on Rails
- Powered by OpenAI
- UI components from Bootstrap
- Icons from Bootstrap Icons
