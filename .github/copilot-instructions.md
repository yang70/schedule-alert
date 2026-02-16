# TourneyPing - Copilot Instructions

## Project Overview
TourneyPing is a web application that monitors sports tournament schedule URLs and notifies users when schedules become available or change.

## Technology Stack
- **Backend**: Ruby 3.3.10, Rails 8.1.2
- **Database**: PostgreSQL
- **Caching**: Redis
- **Background Jobs**: Sidekiq
- **Authentication**: Devise
- **Frontend**: Vue.js with Bootstrap
- **AI Analysis**: OpenAI API (ChatGPT)
- **Notifications**: Email (SendGrid/Mailgun), SMS (future)
- **Deployment**: AWS-ready configuration

## Key Features
1. User authentication with email/password
2. URL monitoring for schedule availability
3. AI-powered schedule change detection
4. Automated email notifications
5. Schedule summaries via AI analysis
6. Per-user data privacy

## Development Guidelines
- Follow Rails 8 conventions
- Use RESTful API design
- Keep controllers thin, models fat
- Write clear, maintainable code
- Use modern JavaScript (ES6+)
- Follow Vue.js composition API patterns

## Project Structure
- `app/models` - User, MonitoredUrl, ScheduleSnapshot models
- `app/jobs` - Sidekiq background jobs for URL checking
- `app/services` - OpenAI integration, notification services
- `app/javascript` - Vue.js components
- `config` - Rails, database, and service configurations
