# TourneyPing implementation status

Implemented following the October 13, 2026 repository review. The verification below describes the checks completed before production rollout. Live OpenAI evaluation and real notification delivery were not part of that verification.

## Product behavior

- A release requires actual game dates and times in the fetched content. TBD opponents or venues are allowed. A PDF link qualifies only when the downloaded PDF contains readable scheduling evidence.
- Release detection is independent of complete game extraction: a failure to extract every game does not suppress a supported release alert.
- Released schedules are checked once daily at 10am Pacific through the tournament start date. Automatic monitoring ends after that date. Earlier unreleased schedules retain adaptive polling.
- Alternate notification recipients require valid email syntax, without an ownership-verification flow.

## Changes

**Accuracy and AI use.** Structured responses distinguish posted, not posted, and unknown; positive results require evidence grounded in the supplied content and tournament dates. Untrusted page content is separated from system instructions. Unknown results, refusals, malformed output, and fetch failures preserve the last successful state. Successful analyses, including negative results, are cached by content, source, tournament date, purpose, model, and prompt version. Normalized game comparisons ignore ordering and cosmetic changes. Model usage and latency metadata are recorded without logging raw source content or credentials.

**Fetching.** Rendering preserves visible table structure, includes supported iframe content, and inspects a bounded number of linked PDFs. Public URL validation and a browser proxy cover DNS resolution, pinned connections, redirects, and subresources. Chrome's sandbox stays enabled. PDF downloads and an isolated parser have size, page, time, and platform-specific resource limits. Partial or unreadable content is reported as uncertainty rather than silently interpreted as an unreleased schedule.

**Background work and delivery.** Manual checks enqueue work and report queued, running, cooldown, and failure states. Database leases and source revisions prevent duplicate dispatch and stale results overwriting edits. Browser jobs have separate bounded concurrency. State changes and durable notification events commit together; delivery uses immutable event payloads so snapshot pruning cannot invalidate queued emails. Delivery failures remain visible and retry with bounded attempts. Checks retry without clearing valid availability or comparison baselines.

**Accounts and UI.** Explicit admin roles replace privilege derived from an editable email address. Existing accounts remain confirmed; new accounts and future account-email changes use Devise confirmation. Cross-account person assignments are rejected and historical assignments are cleared by migration. Controllers return explicit public fields. Quotas, mutation limits, and manual cooldowns bound expensive actions. Dashboard components are precompiled, date arithmetic respects Pacific civil dates and DST, and modals support focus management and keyboard dismissal. Recent notification delivery and check errors are visible.

**Efficiency and operations.** Counter caches and bounded history avoid unbounded association loading. Unused frameworks, duplicate queue systems, build dependencies, and stale templates were removed. Production JavaScript is approximately 351 KB before transfer compression. Ruby and JavaScript dependencies were updated and CI now runs regression, build, lint, and security checks. Mail configuration is environment-driven. Deployment scripts and documentation consistently describe Lightsail/systemd as the scripted deployment, with Docker/Kamal as alternatives.

## Verification

| Check | Result |
| --- | --- |
| Rails regression suite | 42 tests, 198 assertions, no failures or errors |
| JavaScript date/link tests | 4 tests passed |
| Real Chrome fetching fixture | Visible iframe, linked/direct PDF, hidden content, DNS pinning, and private redirect checks passed |
| Local dashboard smoke check | Login, rendering, history, modal keyboard handling, and navigation passed |
| Populated legacy database upgrade | Confirmation backfill, role isolation, counters, foreign-assignment cleanup, and release baseline passed |
| Migration rollback and reapply | Passed on a dedicated test database |
| Production asset compilation | Passed; Sass reports existing Bootstrap/import deprecations |
| Ruby dependency audit / npm audit | No reported vulnerabilities at verification time |
| Brakeman | No warnings or scan errors |
| RuboCop | No offenses |
| Rails autoload validation, shell syntax, diff whitespace | Passed |
| Kamal configuration | Validated locally; deployment not executed |

Tests use dedicated test databases, stubbed OpenAI responses, and test mail delivery. The Chrome fixture uses a controlled local server and mocked public-address routing; it does not establish compatibility with every third-party provider.

## Rollout

Follow [DEPLOYMENT.md](DEPLOYMENT.md) for the Lightsail/systemd path. The deployment scripts pull committed code, so changes must first be reviewed, committed, and published to the deployment branch.

Before upgrading: back up the database, install Node 22, confirm mail/OpenAI/host settings, and reconcile any case-insensitive duplicate person names. Apply the new migration with the old worker stopped. Existing admin access must be explicitly granted to a trusted confirmed account using `ADMIN_USER_EMAIL=... bundle exec rails admin:grant`; `ADMIN_EMAIL` only selects the notice recipient. Build assets, refresh systemd units, restart services, and check application, worker, queue, browser, and mail health. The full procedure and recovery guidance are in the deployment guide.

## Remaining limits

- The optional live evaluation command, `bin/evaluate-schedules`, and representative real provider pages still need evaluation with an OpenAI key. No measured provider accuracy or model comparison is claimed.
- Scanned/image-only PDFs need OCR and remain unsupported. Highly interactive providers, inaccessible documents, oversized sources, or more linked documents than the configured bounds can yield an explicit incomplete/unknown result.
- Analysis caching avoids repeated AI calls on identical inputs; fetches are not globally deduplicated across different users monitoring the same page.
- SMTP can duplicate an email if the worker crashes after provider acceptance but before recording delivery. Stable message identifiers and durable events reduce duplicates without claiming exactly-once delivery.
- Docker was unavailable locally. Image build, container sandbox support, and Linux-specific limits require runtime validation before choosing the container deployment.
- The single-host deploy script is an in-place deployment and can briefly interrupt availability. It does not implement atomic release directories.

## Production rollout

Deployed application revision `af153b6` to the existing Lightsail/systemd host on October 14, 2026 Pacific time. The database was backed up in custom format and its archive directory verified before migration. The backup is retained under `/home/ubuntu/backups/schedule/` on the server.

The host was upgraded from Node 20 to Node 22, Linux gem variants were added to the lockfile, the monitoring migration was applied, and the existing owner account received the explicit admin role. Web and worker services were restarted with the updated units. The existing Nginx TLS configuration was preserved while its upstream changed from the former Unix socket to local TCP port 3000.

Public HTTPS health, the home page, and compiled JavaScript/CSS returned HTTP 200. Web, worker, and Nginx services were active; all three scheduled jobs were registered. PDF parsing and a sandboxed Chrome fetch passed on the Linux host. [GitHub CI](https://github.com/yang70/schedule-alert/actions/runs/38676582281) passed for the deployed application revision. Live model accuracy and actual email delivery remain outside these deployment smoke checks.

### Exposure Events compatibility follow-up

An actual manual check revealed that Exposure Events returned HTTP 403 to Chrome's default headless user agent while serving the same public schedule to a standard browser user agent from the same host. Fetching now uses the installed Chrome version's standard user agent. Provider failures report their HTTP status and distinguish denied access from rate limiting. Canceled analytics beacons no longer mark a successfully loaded timetable incomplete; failed game API requests and documents still do.

The affected public schedule loaded completely on the production host with this fix and contained actual game dates and times. The regression suite passed 46 tests with 209 assertions, and the real Chrome fixture passed user-agent rejection, iframe/PDF fetching, DNS pinning, and private redirect checks.
