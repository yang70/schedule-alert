# TourneyPing - AWS Deployment Guide

## Overview
This application is configured for deployment to AWS using Docker containers. You can deploy using either:
1. **AWS ECS (Elastic Container Service)** - Recommended for production
2. **AWS EC2** - For simpler deployments
3. **AWS Elastic Beanstalk** - For automated scaling

## Prerequisites
- AWS Account
- AWS CLI installed and configured
- Docker installed locally
- PostgreSQL database (AWS RDS recommended)
- Redis instance (AWS ElastiCache recommended)

## Environment Variables Required

```bash
# Database
DATABASE_URL=postgresql://username:password@your-rds-endpoint:5432/schedule_production

# Redis (for Sidekiq and caching)
REDIS_URL=redis://your-elasticache-endpoint:6379/0

# OpenAI
OPENAI_API_KEY=your_openai_api_key

# Email (SendGrid or Mailgun)
SMTP_ADDRESS=smtp.sendgrid.net
SMTP_PORT=587
SMTP_DOMAIN=yourdomain.com
SMTP_USERNAME=apikey
SMTP_PASSWORD=your_sendgrid_api_key

# Application
APP_HOST=your-app-domain.com
RAILS_ENV=production
RAILS_LOG_TO_STDOUT=enabled
RAILS_SERVE_STATIC_FILES=enabled
```

## AWS Services Setup

### 1. RDS (PostgreSQL)
```bash
# Create RDS PostgreSQL instance
aws rds create-db-instance \
  --db-instance-identifier schedule-alert-db \
  --db-instance-class db.t3.micro \
  --engine postgres \
  --master-username dbadmin \
  --master-user-password YOUR_PASSWORD \
  --allocated-storage 20
```

### 2. ElastiCache (Redis)
```bash
# Create ElastiCache Redis instance
aws elasticache create-cache-cluster \
  --cache-cluster-id schedule-alert-redis \
  --cache-node-type cache.t3.micro \
  --engine redis \
  --num-cache-nodes 1
```

### 3. ECR (Container Registry)
```bash
# Create ECR repository
aws ecr create-repository --repository-name schedule-alert

# Authenticate Docker to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Build and push Docker image
docker build -t schedule-alert .
docker tag schedule-alert:latest YOUR_AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/schedule-alert:latest
docker push YOUR_AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/schedule-alert:latest
```

### 4. ECS Deployment

#### Create ECS Cluster
```bash
aws ecs create-cluster --cluster-name schedule-alert-cluster
```

#### Create Task Definition (save as task-definition.json)
```json
{
  "family": "schedule-alert",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "256",
  "memory": "512",
  "containerDefinitions": [
    {
      "name": "web",
      "image": "YOUR_AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/schedule-alert:latest",
      "portMappings": [
        {
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "environment": [
        {"name": "RAILS_ENV", "value": "production"}
      ],
      "secrets": [
        {"name": "DATABASE_URL", "valueFrom": "arn:aws:secretsmanager:..."},
        {"name": "REDIS_URL", "valueFrom": "arn:aws:secretsmanager:..."}
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/schedule-alert",
          "awslogs-region": "us-east-1",
          "awslogs-stream-prefix": "web"
        }
      }
    },
    {
      "name": "sidekiq",
      "image": "YOUR_AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/schedule-alert:latest",
      "command": ["bundle", "exec", "sidekiq"],
      "environment": [
        {"name": "RAILS_ENV", "value": "production"}
      ],
      "secrets": [
        {"name": "DATABASE_URL", "valueFrom": "arn:aws:secretsmanager:..."},
        {"name": "REDIS_URL", "valueFrom": "arn:aws:secretsmanager:..."}
      ]
    }
  ]
}
```

#### Register Task Definition
```bash
aws ecs register-task-definition --cli-input-json file://task-definition.json
```

#### Create ECS Service
```bash
aws ecs create-service \
  --cluster schedule-alert-cluster \
  --service-name schedule-alert-service \
  --task-definition schedule-alert \
  --desired-count 1 \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[subnet-xxx],securityGroups=[sg-xxx],assignPublicIp=ENABLED}"
```

### 5. Load Balancer (Optional but Recommended)
```bash
# Create Application Load Balancer
aws elbv2 create-load-balancer \
  --name schedule-alert-alb \
  --subnets subnet-xxx subnet-yyy \
  --security-groups sg-xxx

# Create target group
aws elbv2 create-target-group \
  --name schedule-alert-targets \
  --protocol HTTP \
  --port 3000 \
  --vpc-id vpc-xxx \
  --target-type ip
```

## Alternative: Simple EC2 Deployment

For a simpler deployment on a single EC2 instance:

```bash
# SSH into EC2 instance
ssh -i your-key.pem ec2-user@your-ec2-ip

# Install Docker
sudo yum update -y
sudo yum install docker -y
sudo service docker start
sudo usermod -a -G docker ec2-user

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Clone your repository
git clone your-repo-url
cd schedule-alert

# Create .env file with your credentials
nano .env

# Run with Docker Compose
docker-compose -f docker-compose.production.yml up -d
```

## Docker Compose for Production

Create `docker-compose.production.yml`:

```yaml
version: '3.8'

services:
  web:
    build: .
    ports:
      - "3000:3000"
    environment:
      - RAILS_ENV=production
    env_file:
      - .env
    depends_on:
      - redis
    command: bundle exec puma -C config/puma.rb

  sidekiq:
    build: .
    environment:
      - RAILS_ENV=production
    env_file:
      - .env
    depends_on:
      - redis
    command: bundle exec sidekiq

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
```

## Post-Deployment Steps

1. **Run database migrations:**
```bash
# ECS
aws ecs run-task --cluster schedule-alert-cluster --task-definition schedule-alert --overrides '{"containerOverrides":[{"name":"web","command":["bundle","exec","rails","db:migrate"]}]}'

# EC2
docker-compose -f docker-compose.production.yml run web bundle exec rails db:migrate
```

2. **Create admin user (if needed):**
```bash
docker-compose -f docker-compose.production.yml run web bundle exec rails console
# Then in console:
User.create(email: 'admin@example.com', password: 'secure_password', password_confirmation: 'secure_password')
```

3. **Verify Sidekiq is running:**
- Access Sidekiq dashboard at: https://your-domain.com/sidekiq (only works in development by default)

## Monitoring & Maintenance

- Set up CloudWatch logs for monitoring
- Enable CloudWatch alarms for high CPU/memory usage
- Set up database backups via RDS automated backups
- Monitor Sidekiq queues regularly
- Set up SSL certificate via AWS Certificate Manager

## Cost Estimates (AWS)

Approximate monthly costs:
- ECS Fargate (2 tasks): ~$15-30
- RDS db.t3.micro: ~$15
- ElastiCache cache.t3.micro: ~$12
- ALB: ~$16
- Data transfer: Varies
- **Total: ~$60-75/month** for small-scale deployment

## Scaling

To handle more traffic:
1. Increase ECS service desired count
2. Use larger instance types for RDS and ElastiCache
3. Add read replicas for PostgreSQL
4. Use CloudFront CDN for static assets
5. Enable auto-scaling based on CPU/memory metrics
