# Alternative Docker/Kamal deployment

The default deploy scripts use [Lightsail/systemd](DEPLOYMENT.md). Containers are a separate alternative: do not run both web/worker stacks against the same host ports unintentionally.

The Dockerfile has `development` and `production` targets, uses Node 22 and the npm lockfile, installs Chromium, runs as a non-root user, and exposes Puma on TCP port 3000. The application uses Sidekiq; it does not start Solid Queue. Chromium must have a functioning sandbox in your container runtime. Do not add `--no-sandbox` to work around a runtime that prevents sandbox startup; configure a runtime/seccomp policy that permits Chromium's required sandbox namespaces.

## Docker Compose

Create `.env.production` from the production settings in DEPLOYMENT.md, with a strong `POSTGRES_PASSWORD`. For the container database URL, use a URL-safe password or URL-encode it in a custom `DATABASE_URL`. Supply real SMTP/OpenAI settings and `SECRET_KEY_BASE`.

```bash
docker compose --env-file .env.production -f docker-compose.production.yml build
docker compose --env-file .env.production -f docker-compose.production.yml up -d db redis
docker compose --env-file .env.production -f docker-compose.production.yml run --rm web bundle exec rails db:prepare
docker compose --env-file .env.production -f docker-compose.production.yml up -d web worker
```

Puma is published only on host `127.0.0.1:3000`. Put a TLS reverse proxy in front of it, using the Nginx configuration/bootstrap instructions in DEPLOYMENT.md. PostgreSQL and Redis are not published by the production Compose file. Manage persistent volumes and verified backups separately.

## Kamal

`config/deploy.yml` defines separate web and Sidekiq worker roles and the correct application port. Configure `DEPLOY_HOST`, `KAMAL_IMAGE`, and `KAMAL_REGISTRY_USERNAME` for your own server/image registry before using it. Supply `.kamal/secrets` with:

```dotenv
KAMAL_REGISTRY_PASSWORD=replace_me
SECRET_KEY_BASE=replace_me
DATABASE_URL=postgresql://USER:URL_ENCODED_PASSWORD@DB_HOST/schedule_production
REDIS_URL=redis://REDIS_HOST:6379/0
OPENAI_API_KEY=replace_me
SMTP_PASSWORD=replace_me
```

The template uses SendGrid's SMTP address and username; change those explicit settings for a different provider. Database and Redis hosts must be reachable from the containers; `localhost` in a container refers to that container, not the host's existing services. Provision them independently or configure Kamal accessories. `.kamal/secrets` is ignored by Git.

Use a migration step before deploying the new runtime, and explicitly grant trusted admin accounts as documented in DEPLOYMENT.md. Test the container build, database migration, Chromium sandbox/fetching, email delivery, and health checks on your target runtime before promoting it. Docker is not installed in the implementation workspace, so this alternative has not been exercised there.
