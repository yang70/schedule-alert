# Deploy TourneyPing on Lightsail

The deploy scripts use a single Ubuntu server with systemd, Puma, Sidekiq, Nginx, PostgreSQL, Redis, and Google Chrome. Docker and Kamal are alternatives; they are not used by `bin/deploy.sh` or `bin/deploy-remote.sh`.

## Initial setup

1. Create an Ubuntu 22.04 instance and attach a static IP. Configure the domain's DNS. Allow inbound SSH, HTTP, and HTTPS; keep PostgreSQL, Redis, and Puma private.
2. Run `bin/lightsail-setup.sh` on the instance. It installs Ruby 3.3.10, Node 22, Chrome, and the required server packages. Run Chrome as the application user with its sandbox enabled.
3. Clone the repository to `/home/ubuntu/schedule`.
4. Create `.env.production` with mode `600`:

```dotenv
RAILS_ENV=production
SECRET_KEY_BASE=replace_with_output_of_bundle_exec_rails_secret
DATABASE_URL=postgresql://ubuntu:URL_ENCODED_PASSWORD@localhost/schedule_production
REDIS_URL=redis://localhost:6379/0
OPENAI_API_KEY=replace_me
OPENAI_MODEL=gpt-4o-mini
CHROME_PATH=/usr/bin/google-chrome
BROWSER_CONCURRENCY=1
DB_POOL=10
MAX_URLS_PER_USER=50
PUMA_BIND=tcp://127.0.0.1:3000
SMTP_ADDRESS=smtp.sendgrid.net
SMTP_PORT=587
SMTP_DOMAIN=tourneyping.com
SMTP_USERNAME=apikey
SMTP_PASSWORD=replace_with_sendgrid_key
FROM_EMAIL=noreply@tourneyping.com
APP_HOST=tourneyping.com
ADMIN_EMAIL=trusted-owner@example.com
```

For Resend, omit `SMTP_ADDRESS`, `SMTP_USERNAME`, and `SMTP_PASSWORD`, and set `RESEND_API_KEY`. Do not configure both paths. `ADMIN_EMAIL` only receives notices. It does not make an account an admin. `RAILS_MASTER_KEY` is optional if you continue using encrypted Rails credentials; all integration credentials above come from the environment.

5. Load the environment, install dependencies, migrate, and build:

```bash
cd ~/schedule
set -a
source .env.production
set +a
bundle config set --local without 'development test'
bundle config set --local deployment true
bundle install
npm ci
bundle exec rails db:prepare
NODE_ENV=production bundle exec rails assets:precompile
sudo cp config/systemd/tourneyping-*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now tourneyping-web tourneyping-worker
```

Puma listens only on `127.0.0.1:3000`. There is no Unix socket directory to bootstrap. The web and worker services load `.env.production` directly.

6. Install the HTTP-only Nginx bootstrap configuration, then obtain TLS certificates:

```bash
sudo cp config/nginx/tourneyping.conf /etc/nginx/sites-available/tourneyping.conf
sudo ln -s /etc/nginx/sites-available/tourneyping.conf /etc/nginx/sites-enabled/tourneyping.conf
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl reload nginx
sudo certbot --nginx --redirect -d tourneyping.com -d www.tourneyping.com
sudo nginx -t
sudo systemctl reload nginx
```

The repository config deliberately has no certificate paths, so a fresh host can pass validation before Certbot runs. Keep Certbot's generated TLS configuration in `/etc/nginx`; future application deployments do not overwrite it.

## Upgrading an existing installation

Install Node 22 before running the updated deploy script. If using nvm, install the version in `.node-version`; the script uses `nvm use` when nvm is present. Save a database backup first.

The monitoring migration adds explicit admin roles, account email confirmation, monitoring leases/revisions, analysis caching, and notification events. Existing accounts remain confirmed to preserve access; new registrations and future email changes require confirmation. Alternate notification recipients remain unverified.

**Existing admins must be explicitly granted a role after migrating.** Review the intended account's ownership before granting it:

```bash
# On the server after the migration, with .env.production loaded:
ADMIN_USER_EMAIL=trusted-owner@example.com bundle exec rails admin:grant
```

Do not assume the account matching the old `ADMIN_EMAIL` setting is trustworthy simply because that email was registered. Admin fields are not accepted through public registration/profile parameters.

The migration removes cross-account person assignments and seeds already-released URLs to avoid sending old release alerts again. Case-insensitive duplicate person names must be reconciled before migration; it aborts rather than rename or delete those records. Inspect duplicates with:

```sql
SELECT user_id, LOWER(name), COUNT(*)
FROM people GROUP BY user_id, LOWER(name) HAVING COUNT(*) > 1;
```

## Subsequent deployments

```bash
# On the server:
cd ~/schedule
./bin/deploy.sh

# Or from your workstation:
LIGHTSAIL_KEY_FILE=/path/to/key.pem ./bin/deploy-remote.sh
```

The remote wrapper calls the same server script. That script loads production settings, rejects tracked local modifications, pulls with `--ff-only`, installs locked dependencies, builds assets, stops the worker for migration, refreshes systemd service definitions, restarts both services, and checks application and service health. It reports the previous Git revision for recovery.

`DEPLOY_HOST`, `DEPLOY_USER`, and `LIGHTSAIL_KEY_FILE` select the remote destination. No script silently stashes local changes. Deployments are in-place on this single host and can briefly interrupt availability; they are not an atomic release-directory deployment.

## Operations and recovery

```bash
sudo journalctl -u tourneyping-web -u tourneyping-worker -f
sudo systemctl status tourneyping-web tourneyping-worker nginx
curl --fail -H 'Host: tourneyping.com' http://127.0.0.1:3000/up
./bin/production-console
```

The dashboard shows check errors and recent email delivery state. Failed checks retry after 1, 5, and 15 minutes, then return to normal polling. Unreadable content never erases the last successful schedule. Running checks use 15-minute leases; queued checks have a six-hour recovery window so a busy queue does not repeatedly replace jobs that are still waiting. Monitor queue latency and increase capacity before it approaches that window. Released schedules run once daily at 10am Pacific through their start date.

Email events retry up to eight attempts; permanent SMTP rejections stop sooner. Fix provider credentials/recipient problems before deliberately retrying a failed event from the console:

```ruby
event = NotificationEvent.find(EVENT_ID)
# If the original recipient needs correction, explicitly replace it here:
# event.payload = event.payload.merge("recipient" => "corrected@example.com")
event.update!(delivery_attempts: 0, last_error: nil, next_delivery_at: Time.current)
DeliverNotificationJob.perform_later(event.id)
```

Take and verify database backups outside the app host. For a failed deployment, inspect logs and the reported previous revision first. If the additive migration completed, you can restore the previous code/dependencies/assets and restart services without immediately dropping the new columns. Do not run a database rollback while the new app is running; rollback removes notification history and the new monitoring fields. Use a maintenance window and a verified backup for database recovery.

Browser traffic uses a proxy that blocks private/reserved destinations, pins resolved IPs, and covers redirects/subresources. Chrome's sandbox stays enabled. PDF downloads and parsing have time, size, and page-count limits. Containers require equivalent sandbox support; see [AWS_DEPLOYMENT.md](AWS_DEPLOYMENT.md).
