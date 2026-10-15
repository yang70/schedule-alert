# TourneyPing

TourneyPing monitors the tournament schedule page you supply and emails you when a schedule is released or meaningfully changes. OpenAI evaluates different providers' pages instead of requiring a custom parser for each provider.

A released schedule needs real game dates and times. Opponents and venues may still be TBD. Relevant linked PDFs and visible HTML iframes are included when their contents can be read. A link alone is not release evidence. Image-only PDFs, unreadable documents, challenges, and ambiguous responses preserve the last successful state and produce a visible check warning or error.

Before release, check times adapt to tournament proximity, with extra Tuesday checks. After release, checks run once daily at 10am Pacific, through the start date. Automatic checks stop after that date. A minute dispatcher honors the scheduled times; it does not fetch every URL every minute.

## Local setup

Requirements: Ruby 3.3.10, Node 22 (see `.node-version`), PostgreSQL, Redis, and Chrome or Chromium with its sandbox enabled.

```bash
cp .env.example .env
# Fill in OpenAI and SMTP credentials. Set CHROME_PATH if needed.
bundle install
npm ci
# Use existing local PostgreSQL/Redis, or start containers:
docker compose up -d db redis
# With container PostgreSQL, set DATABASE_URL to
# postgresql://postgres:password@localhost:5432/schedule_development
bin/rails db:prepare
bin/dev
```

Visit http://localhost:3000. New accounts confirm their account email before signing in. Alternate notification email addresses require only a valid format, with no ownership verification.

`docker compose --profile app up --build` is an optional container development path. Browser sandbox support must be available in the container runtime; disabling Chrome's sandbox is not supported.

## Architecture

- Rails, PostgreSQL, Devise, Vue, Bootstrap, and Sidekiq.
- Manual checks return immediately with a queued status; the dashboard refreshes every 15 seconds while visible.
- A separate Sidekiq capsule bounds browser concurrency (default one), leaving capacity for dispatch and email delivery.
- Browser navigation, redirects, and subresources use a validating proxy that rejects private/reserved addresses and connects to a checked IP. PDF downloads apply the same checks and bound size/time. PDF parsing runs in a separate process with CPU/output limits.
- AI release classification and game-detail extraction are separate. Missing details cannot suppress a grounded release alert. Successful analyses, including “not posted,” are cached by source, tournament date, content, model, and prompt version.
- Complete game timetables are normalized before comparison. Partial detail extraction preserves the previous comparison baseline and is retried at the next check.
- Per-URL leases prevent overlapping checks. Source/date edits create a new revision so old results cannot overwrite the new source.
- State transitions and immutable email events commit together. Email delivery retries independently; pending events survive snapshot pruning. Compact notification history is retained while only two full page snapshots remain.

SMTP delivery has an unavoidable ambiguity if a process dies after the provider accepts a message but before the database records delivery. Stable Message-IDs help identify such duplicates; SMTP does not guarantee exactly-once delivery.

## Configuration

See `.env.example`. Important settings include:

| Setting | Default / purpose |
| --- | --- |
| `OPENAI_MODEL` | `gpt-4o-mini`; changing it invalidates analysis cache keys |
| `CHROME_PATH` | Automatic browser discovery unless supplied |
| `BROWSER_CONCURRENCY` | `1`; increase only after measuring memory and latency |
| `DB_POOL` | `10`; cover total Sidekiq concurrency if increased |
| `MAX_URLS_PER_USER` | `50` retained monitored URLs |
| `SMTP_*` | Environment-driven SMTP, including SendGrid/Mailgun |
| `RESEND_API_KEY` | Resend fallback when `SMTP_ADDRESS` is absent |
| `ADMIN_EMAIL` | Signup/bot-summary recipient only; grants no privileges |

Admin roles must be explicitly provisioned for a trusted account. See [DEPLOYMENT.md](DEPLOYMENT.md). Public signup remains enabled, with request limits and signed signup timing tokens. Manual checks have a five-minute cooldown and account request limits.

## Verification

Use a dedicated test database; never point tests at development or production data.

```bash
RAILS_ENV=test DATABASE_URL=postgresql:///schedule_test bin/rails db:prepare
RAILS_ENV=test DATABASE_URL=postgresql:///schedule_test bin/rails test
npm test
NODE_ENV=production npm run build
npm run build:css
# Optional real Chrome smoke test with local fixtures (no OpenAI calls):
RAILS_ENV=test bin/rails runner bin/check-fetching
bin/rubocop
bin/brakeman --no-pager --exit-on-warn --exit-on-error
bin/bundler-audit check --update
npm audit
```

Routine tests mock HTTP/OpenAI boundaries and send mail only to Rails' test delivery store. An optional live release evaluation is available with `bin/rails runner bin/evaluate-schedules`; it calls OpenAI using your configured key and reports expected classifications, latency, and token usage. Keep it separate from routine CI.

The supported default production path is [Lightsail/systemd](DEPLOYMENT.md). [AWS_DEPLOYMENT.md](AWS_DEPLOYMENT.md) describes the alternative Docker/Kamal path; the two deployment methods are alternatives, not layers of the same setup.
