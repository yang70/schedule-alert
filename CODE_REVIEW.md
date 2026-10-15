# TourneyPing repository review

Reviewed October 13, 2026. This document records the findings before implementation. The follow-up implementation is described in IMPLEMENTATION.md.

## Product intent confirmed during the review

- The primary benefit is knowing that a tournament schedule has been released, across different providers, using the page supplied by the user.
- A schedule with real game dates and times counts as released even if venues or opponents are TBD. Extracting every team's games is secondary to that alert.
- Continue monitoring for changes after release, at a lower frequency such as once daily.
- Stop automatic monitoring after the tournament start date. Multi-day monitoring is deliberately outside the current scope.
- Alternate notification email addresses do not require ownership verification. Validate their format and handle delivery failures without adding a verification flow.
- A linked PDF can qualify as a released schedule when its contents show scheduling information under the same release rule: real game dates and times, with TBD venues or opponents allowed. A link by itself is insufficient evidence.
- The deployment scripts implement a single Ubuntu server with Puma, Sidekiq, Nginx, PostgreSQL, Redis, and systemd. Docker/Kamal is an alternative configuration, not a component of that deployment, and is currently incomplete. This conclusion is based on repository files; the running server was not inspected.

## Scope and validation

Reviewed the application controllers, models, jobs, OpenAI service, Vue dashboard and lifecycle code, mailers/templates, routes, migrations/schema, styles, environment configuration, build configuration, CI, deployment scripts, and deployment documentation. Generated database schemas and unused framework scaffolding were also considered when assessing complexity.

| Check | Result |
| --- | --- |
| `bundle check` | Dependencies installed and satisfied locally |
| `npm run build` | Passed |
| `npm run build:css` | Completed; Bootstrap/Sass deprecation warnings |
| `bundle exec rails test` | **0 tests, 0 assertions**; no regression coverage |
| `bundle exec rubocop --format simple` | 51 files inspected; one trailing-whitespace offense in `app/jobs/url_check_job.rb:18` |
| Brakeman 8.0.2 | One weak-confidence unsafe-link warning at `app/views/admin/users/show.html.erb:67`; no scan errors |
| `bundle exec bundler-audit check --update` | **164 advisory matches across 24 gems**; advisory database updated October 10, 2026 |
| `npm audit --json` | **17 package vulnerabilities: 13 high, 3 moderate, 1 low** |
| Isolated reproductions using real job/scheduling methods and mocked dependencies | Confirmed failure-state corruption, duplicate recovery notification, false change notification on reordering, repeated AI calls on unchanged waiting pages, unsafe URL acceptance, hourly dispatch mismatch, UTC/Pacific cutoff, and frontend DST arithmetic |

Advisory counts are scanner matches, not proof of that many exploitable application paths. Several concern unused frameworks, development tools, or platforms other than the deployed platform. No live OpenAI calls, notification deliveries, production database changes, deployment, or browser exploit attempts were made. The mocked checks establish application control flow; provider-specific extraction accuracy and live concurrency still need integration tests.

## Findings to address first

### 1. High: admin privilege depends on an unverified, editable email

**Files:** `app/models/user.rb:4`, `app/models/user.rb:13`, `config/routes.rb:2`.

`admin?` compares the account email to `ADMIN_EMAIL`, while Devise does not enable email confirmation. If the configured admin address is not already occupied by a legitimate account, anyone can register it, or change their own account email to it, without owning the mailbox. That gives access to all users' data and account deletion. The unique email index prevents this route while a legitimate account already occupies that address, but changing the admin address or deleting that account reopens the condition.

**Recommendation:** Assign an explicit admin role to a trusted account through an administrative provisioning process. Do not derive privilege from editable profile fields. Verify email ownership for public registrations and email changes. Add authorization tests covering signup, email changes, and ordinary users accessing admin endpoints.

### 2. High: user-supplied URLs allow internal network access and unsafe schemes

**Files:** `app/models/monitored_url.rb:8`, `app/jobs/url_check_job.rb:26`, `app/views/admin/users/show.html.erb:67`.

The URL validation searches for an HTTP(S) substring rather than validating the entire URI. It accepts `javascript:alert('https://example.test')`, localhost URLs, and cloud metadata addresses. Accepted values reach both the headless browser and link rendering. Even a strict HTTP(S) parser would still permit server-side requests into private networks without additional controls. Redirects, DNS resolution changes, and browser subresource requests must also be covered.

**Recommendation:** Parse the complete URL, require an HTTP(S) scheme and hostname, and reject credentials and disallowed ports. Run fetching in an isolated process/container with egress controls that block loopback, private/link-local networks, and metadata endpoints for navigation, redirects, and subresources. Enable the browser sandbox in a supported environment; `no-sandbox` currently executes arbitrary public-page JavaScript as the worker's OS user. Treat the Brakeman link warning as actionable alongside this validation failure, although browser execution was not tested.

### 3. High: a foreign `person_id` leaks another user's record

**Files:** `app/controllers/monitored_urls_controller.rb:100`, `app/models/monitored_url.rb:3`, `app/controllers/monitored_urls_controller.rb:20`, `app/controllers/monitored_urls_controller.rb:90`.

The monitored URL itself is scoped to the current user, but its permitted `person_id` is not. An authenticated user can assign a guessed person ID belonging to another account. Subsequent JSON responses expose that person's name and color; `check_now` includes the complete person serialization.

**Recommendation:** Resolve the assignment through `current_user.people` and validate matching ownership in the model. Return an explicit attribute allowlist consistently from every endpoint. Test cross-account association assignments.

### 4. High: fetch and AI failures corrupt successful monitoring state

**Files:** `app/services/open_ai_service.rb:59`, `app/services/open_ai_service.rb:62`, `app/jobs/url_check_job.rb:30`, `app/jobs/url_check_job.rb:95`, `app/jobs/url_check_job.rb:110`, `app/jobs/url_check_job.rb:122`.

The service converts API errors into `schedule_available: false` and `schedule_data: nil`. The job persists those results as a normal snapshot, replacing a useful comparison baseline and clearing availability. HTTP 403/429 responses also clear availability; server error pages can proceed to AI analysis. Recovery then appears to be a new release and sends another availability email. The broad job rescue hides failures from Sidekiq, so its normal exception-based retries cannot recover them. The dispatcher has already moved the next check forward.

**Confirmed:** A mocked API failure replaced a valid schedule baseline with `nil`; recovery with identical games produced an `:available` email. A mocked 403 cleared availability.

**Recommendation:** Represent fetch/analysis failure separately from a successful “not posted” classification. Preserve the last successful state and snapshot, record `last_attempt_at`, `last_success_at`, and an error category, and retry transient errors with bounded backoff. Handle response refusal, missing content, and incomplete output before parsing. Official OpenAI documentation explicitly describes refusal and incomplete-output handling for [Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs). Ensure browser initialization/header setup is inside cleanup protection, and avoid dereferencing a missing monitored URL in the rescue logger.

### 5. High: the release rule contradicts the intended product behavior

**File:** `app/services/open_ai_service.rb:79`.

The initial prompt requires field/venue assignments and specific team matchups and treats placeholders strictly. That can classify a released schedule with real dates/times and TBD fields or opponents as unavailable. The subsequent comparison prompt uses a different availability definition, further reducing consistency.

**Recommendation:** Use one explicit release definition for every check: evidence of a published tournament game timetable, with real dates and times; partial venues/opponents are allowed. Separate “not posted” from “could not determine.” Pass the tournament date and source context so old schedules on the same page do not qualify automatically. Request short supporting evidence rather than requiring complete extraction of every game to send the release alert.

### 6. High: overlapping checks and partial writes can duplicate or lose notifications

**Files:** `app/jobs/check_all_urls_job.rb:6`, `app/jobs/url_check_job.rb:62`, `app/jobs/url_check_job.rb:95`, `app/jobs/url_check_job.rb:110`, `app/jobs/url_check_job.rb:116`.

There is no per-URL job claim, version check, transaction around the state transition, or unique notification event. A manual check can overlap a scheduled check. Both may read the same baseline and queue the same email, or a slow older fetch may overwrite a newer result. If snapshot creation succeeds but the state update fails, a later run can skip notifying because it sees an already-written baseline. If email enqueue fails after availability is updated, an unchanged page will no longer trigger the release notification.

**Recommendation:** Use a short atomic claim/lease per URL, include a source revision in each job, and commit the successful snapshot, state transition, and unique notification event in one database transaction. Deliver pending events independently and idempotently. Do not hold a database lock through browser/API calls. Atomically claim due URLs in the dispatcher as well.

### 7. High: snapshot pruning can break queued emails

**Files:** `app/jobs/url_check_job.rb:104`, `app/jobs/url_check_job.rb:119`, `app/mailers/notification_mailer.rb:15`.

`deliver_later` receives Active Record snapshots that Active Job serializes using GlobalID. Another check can delete a referenced snapshot before the mail job deserializes it. For example, the email for A→B carries A and B; the next check C deletes A because only two snapshots are retained. The old snapshot is passed even though the current email templates never use it.

**Recommendation:** Give notification events immutable payloads containing the recipient, source URL, evidence/summary, timestamps, and relevant change details. Retain referenced records until delivery is complete if record arguments are retained. Remove the unused old-snapshot argument. Keep compact event history separately from large page-content snapshots.

### 8. High: manual checking blocks web requests and reports failures as success

**Files:** `app/controllers/monitored_urls_controller.rb:81`, `config/puma.rb:28`, `app/javascript/components/Dashboard.js:272`.

`check_now` runs Chrome and OpenAI synchronously inside Puma. The local `ruby-openai` version defaults to a 120-second request timeout, in addition to browser startup/navigation waits. With three default Puma threads, a few slow checks can occupy the web server. Swallowed job errors still return HTTP 200 and old data. There are no server-side check cooldowns or account limits.

**Recommendation:** Enqueue checks and return HTTP 202 with a job/status identifier. Poll briefly or push completion updates, show success/error/queued states, and enforce cooldowns and account quotas. Use separate bounded browser-job capacity so expensive checks do not consume all notification workers.

### 9. High: documented email credentials do not configure the application

**Files:** `DEPLOYMENT.md:48`, `.env.example`, `config/environments/production.rb:63`, `config/environments/development.rb`.

Deployment instructions and the example environment supply SendGrid/Mailgun `SMTP_*` credentials. The application configures authenticated SMTP only when `RESEND_API_KEY` is present, and hardcodes Resend. Following the guide does not establish the advertised notification delivery path. Without Resend, Rails retains its default SMTP behavior rather than using those documented credentials.

**Recommendation:** Choose and document the supported email provider, or implement one shared environment-driven SMTP configuration. Validate required settings at startup and test release alerts and password-reset delivery using a controlled mailbox. Show notification failures in operations monitoring.

### 10. High: dependency security audits fail

**Files:** `Gemfile.lock`, `package-lock.json`, `.github/workflows/ci.yml`, `.github/dependabot.yml`.

Ruby audit matches include Rails 8.1.2, Rack 3.2.4, Devise 5.0.0, Faraday 2.14.0, Nokogiri 1.19.0, and Puma 7.2.0, along with other transitive dependencies. JavaScript audit matches include Vue, PostCSS, and several build/watch dependencies. Prioritize server-facing dependencies and the HTML parser used on untrusted pages; assess applicability before describing unused-feature advisories as exploitable.

**Recommendation:** Upgrade compatible dependencies, regenerate lockfiles, and run behavior tests plus audits. Remove unused dependencies where practical. Add npm audit/build checks and npm Dependabot updates; current Dependabot configuration covers Bundler and GitHub Actions only. Avoid an indiscriminate `npm audit fix --force`: the audit suggests major changes and even a nodemon downgrade for some dependency chains. Examples of confirmed patch advisories are [Rack multipart parsing](https://github.com/rack/rack/security/advisories/GHSA-v6x5-cg8r-vv6x) and [Rails Action View helpers](https://github.com/rails/rails/security/advisories/GHSA-v55j-83pf-r9cq).

## Accuracy, resource usage, and lifecycle findings

### 11. Medium: raw game-array comparison generates false changes

**File:** `app/jobs/url_check_job.rb:85`.

Ruby array equality is sensitive to game order and literal string formatting. The same games in reversed order send a change alert, even when the model returns `schedule_changed: false`; that response field is assigned and never used. Date/time formatting and team aliases create similar noise. The email displays the full new schedule and normally suppresses the change summary when rows exist.

**Confirmed:** Identical games returned in reverse order produced an `:changed` email.

**Recommendation:** Compare canonical game sets or a structured list of meaningful changes. Normalize dates/times, timezone, whitespace, and ordering without discarding intentional home/away changes. Support cancelled/postponed games and partial opponents. Use stable provider game IDs when available. Show the changed items explicitly in update emails. Retain game extraction for secondary change monitoring, without making it a prerequisite for the release alert.

### 12. Medium: unchanged waiting pages repeatedly spend AI tokens

**File:** `app/jobs/url_check_job.rb:68`.

Unchanged content skips AI only when `schedule_available` is true. A successfully analyzed “coming soon” page is analyzed again at every scheduled/manual check. Entire old and new page text is also sent for comparisons, and users monitoring the same page each launch their own browser and analysis.

**Confirmed:** Two checks of an unchanged, previously analyzed waiting page made two AI calls.

**Recommendation:** Cache every successful analysis by relevant-content hash plus model/prompt/schema version, including negative classifications. Retry failed analyses separately, and allow controlled reanalysis for date-sensitive/provider-sensitive cases. Extract current schedule data once when change monitoring needs it, compare with stored canonical data in Ruby, and generate a summary only for a real change. As usage grows, share fetch/analysis results per normalized source URL while keeping subscriptions, recipient choices, and notification history private.

### 13. Medium: dispatch timing and post-release frequency do not match requirements

**Files:** `config/sidekiq.yml:11`, `app/models/monitored_url.rb:28`, `app/models/monitored_url.rb:52`, `app/jobs/check_all_urls_job.rb:9`.

The cron dispatcher runs hourly, while Tuesday slots include 10:45, 11:30, and 12:15. In a punctual simulation the intended six checks became five checks at 10:00, 11:00, 12:00, 13:00, and 17:00; the 12:15 slot was skipped. Scheduling also ignores whether release has already been detected, so released URLs retain the higher pre-release frequency. `next_check_at` is advanced on enqueue rather than after a successful check.

**Recommendation:** Dispatch every minute or a few minutes while atomically selecting only due URLs, or enqueue exact scheduled times with cancellation/version handling. Use the current adaptive schedule while waiting, then once daily after release through the start date. Keep retry timing distinct from routine scheduling. Return the server's schedule policy in the API instead of duplicating it in JavaScript. Correct README's 15-minute claim and the landing page's “the moment” promise to match the actual alert delay.

### 14. Medium: date calculations mix UTC, Pacific time, and browser local time

**Files:** `config/application.rb`, `app/models/monitored_url.rb:17`, `app/models/monitored_url.rb:23`, `app/models/monitored_url.rb:54`, `app/javascript/components/Dashboard.js:311`, notification email templates.

Rails has no configured app timezone, so `Date.current` defaults to UTC, while scheduled check times use Pacific. At 6pm Pacific on October 14, UTC already considers an October 14 tournament past; eligibility excludes it and its later evening checks. The frontend uses the browser's date and divides elapsed milliseconds by 24 hours. Across the November DST transition, October 31→November 2 returns three days instead of two. Email check timestamps omit the timezone.

**Recommendation:** Define the product timezone explicitly and use its civil date consistently for eligibility and cutoff. Calculate browser day differences using date components or return server-calculated days/policy. Label email timestamps with the chosen timezone. Test midnight and both DST transitions. Stopping after the start date remains intentional; the bug is stopping partway through that date.

### 15. Medium: editing tournament dates does not reschedule correctly

**File:** `app/models/monitored_url.rb:14`.

The `after_save` condition uses `tournament_start_date_changed?`, which describes pending changes; after saving, changes have already been applied. Editing the tournament date can leave an obsolete `next_check_at`.

**Recommendation:** Use `saved_change_to_tournament_start_date?` in the after-save callback, or calculate scheduling attributes before persistence using the corresponding pending-change predicate. Rails documents [saved-change predicates for after callbacks](https://api.rubyonrails.org/classes/ActiveRecord/AttributeMethods/Dirty.html). Also recalculate when the monitoring policy, active status, or release status changes.

### 16. Medium: changing the source URL preserves unrelated state

**File:** `app/controllers/monitored_urls_controller.rb:52`.

Editing a URL retains availability, old snapshots, and comparison data without an immediate recheck. The next run compares different tournaments and may send a misleading change email or suppress a new release email. A check already in progress can write the old page's result against the edited URL.

**Recommendation:** Treat a source URL change as a new monitoring revision, reset its baseline and release-notification eligibility, enqueue an immediate check, and reject results from older revisions. Preserve old history with its source identity if history is desired.

### 17. Medium: page preparation loses context and can miss published schedules

**Files:** `app/jobs/url_check_job.rb:38`, `app/jobs/url_check_job.rb:49`, `app/services/open_ai_service.rb:146`.

Removing scripts/styles and using `doc.text.squish` does not isolate visible schedule content. It includes navigation, hidden content and unrelated text, removes table-row boundaries, and loses link destinations. Waiting for network idle does not guarantee schedule rendering or complete pagination, and can fail on pages with persistent requests. An iframe, linked PDF, tabbed schedule, or paginated listing may be missed. Keeping only the first 50,000 characters can omit the timetable entirely.

**Recommendation:** Keep provider-agnostic AI classification, but preserve headings, table rows, relevant links, and date context in its input. Fetch relevant linked PDFs through the same isolated fetching controls, extract their contents, and apply the release rule to that evidence. Use bounded download sizes, timeouts, and parsing limits. A PDF link alone should not trigger the release alert; inaccessible or unreadable PDFs should leave the result uncertain and preserve the last successful state. Exclude obvious layout noise, expose detected login/challenge/error pages as check failures, and use bounded rendering readiness checks. Add fixtures for released and unreleased PDFs, inaccessible documents, iframes, and tabbed pages. An HTTP fetch can be used for pages known to contain their schedule in server-rendered HTML; use Chromium where JavaScript rendering is required. Make the browser path configurable for local development and containers.

### 18. Medium: the AI contract enforces shape without verifying evidence

**Files:** `app/services/open_ai_service.rb:19`, `app/services/open_ai_service.rb:37`, `app/services/open_ai_service.rb:126`.

Strict JSON Schema is already a good choice. However, arbitrary strings for dates/times/venues do not establish that games exist in the current tournament, and page instructions are interpolated into the same user message as the analysis request. The service stores no model/prompt version, usage, request ID, or validation evidence. Low temperature does not guarantee stable extraction.

**Recommendation:** Put the release policy in a trusted instruction message; delimit the scraped page as untrusted evidence and explicitly prohibit following its instructions. Treat delimiters as clarity aids, not a complete security boundary. Return an evidence-based release classification with uncertainty; validate source evidence and date consistency before changing state. Keep unknown values nullable in secondary game extraction. Log model, prompt/schema version, token usage, latency, and error category without logging credentials or full sensitive pages. Official guidance supports [clear instruction/context boundaries](https://developers.openai.com/api/docs/guides/prompt-engineering).

Build a labeled set of real provider pages and expected transitions: unreleased, posted with TBD opponents/venues, archived schedules, challenge pages, changed game time, reordered games, and removed/cancelled games. Measure release precision/recall, change-alert precision, cost, and latency before changing models. This applies OpenAI's [evaluation guidance](https://developers.openai.com/api/docs/guides/evaluation-best-practices) to this app. A model upgrade or API migration should follow those measurements; it is not a prerequisite for fixing the current logic.

## Deployment and maintainability findings

### 19. High for fresh deployment: the setup paths contain concrete blockers

**Files:** `bin/deploy.sh:22`, `bin/deploy-remote.sh:22`, `config/puma.rb:34`, `Dockerfile:39`, `Dockerfile:57`, `config/deploy.yml`, `config/nginx/tourneyping.conf`, `DEPLOYMENT.md`.

The active scripts SSH to Ubuntu, pull code, compile assets, migrate, and restart systemd services. They do not run Docker or Kamal. The remote script loads `.env.production`; the documented direct `bin/deploy.sh` path does not, and production excludes `dotenv-rails`. A fresh shell following the direct path can therefore run Rails tasks without database/secrets configuration. The scripts also differ in Bundler configuration and Git behavior.

Fresh Lightsail setup does not create `tmp/sockets`, but Puma binds to a socket inside it; the installed Puma binder does not create the parent directory. The checked-in Nginx configuration already references Let's Encrypt certificate files, although the instructions copy it before obtaining certificates. That can fail Nginx configuration validation during certificate bootstrap.

Docker has independent failures: it copies a nonexistent `yarn.lock` although the repo uses npm; its Node/toolchain setup differs from the npm path; the final image lacks Chrome; production Puma binds to an Ubuntu-specific socket instead of the expected container TCP port. Compose mounts source at `/app` while the image works at `/rails`, and uses the production image/bundle exclusions for development. Kamal starts Solid Queue even though jobs target Sidekiq, has no active Sidekiq server role, and omits required application environment configuration. AWS container instructions repeat port/environment mismatches.

**Recommendation:** Make Lightsail/systemd the documented supported path unless a working container deployment is actually needed. Consolidate deployment scripts, explicitly load required production environment, use lockfile-based installs, create the socket directory with correct ownership, and use a certificate-free HTTP config for initial TLS setup. Add a post-deploy health check and rollback procedure. If containers are required, implement and smoke-test them as a complete alternative: consistent npm/Node tooling, Chrome and sandbox support, TCP Puma binding, Sidekiq, PostgreSQL/Redis, required secrets, and explicit migration handling.

### 20. Medium: CI does not verify application behavior

**Files:** `.github/workflows/ci.yml`, `config/ci.rb`, `bin/setup`, `config/application.rb`.

No test/spec suite exists; `rails test` succeeds with zero work. CI checks Ruby lint/security but does not exercise release transitions, ownership, scheduling, JS/CSS builds, or deployment startup. Setup/local CI still use Yarn despite the committed npm lockfile.

**Recommendation:** Add focused tests for the high-risk behavior in this report and make zero-test execution visible. Use PostgreSQL for transactional/ownership tests, mock fetch/OpenAI/mail boundaries for routine CI, and add JS build/template checks plus a deployment smoke check. Keep paid model/provider evaluation separate from deterministic CI.

### 21. Medium: dashboard state and Turbo lifecycle can become stale

**Files:** `app/javascript/application.js:14`, `app/javascript/components/Dashboard.js:75`, `app/javascript/components/Dashboard.js:118`.

The dashboard loads once; after adding a URL it immediately reloads, often before the background check finishes, and has no completion refresh. Data-load failures are logged but can look like an empty successful dashboard. Turbo caches cloned DOM containing `data-vue-mounted`, while Vue instances/listeners are not restored with that clone. The mount guard can therefore skip initializing a restored dashboard.

**Recommendation:** Unmount and clear the Vue mount marker before Turbo caching, or intentionally disable caching for this page. Refresh after job completion and when returning to the page, surface actionable load/check errors, and display backend validation messages. Add a navigation test covering dashboard → another page → back.

### 22. Lower priority: avoid unnecessary data loading and UI/build complexity

**Files:** `app/controllers/dashboard_controller.rb:5`, `app/controllers/admin/users_controller.rb:3`, `app/controllers/monitored_urls_controller.rb:12`, `db/schema.rb`, `app/javascript/components/Dashboard.js`, `esbuild.config.js`.

The HTML dashboard controller loads URLs and snapshots even though its view contains only a Vue mount point; Vue then fetches URLs again. JSON queries recent snapshots that the component ignores. Snapshot includes load large content fields when only counts are needed. Admin listings load all users and associations without pagination. Due-check filtering lacks a corresponding scheduling index. Person name validation is case-insensitive while its database unique index is case-sensitive.

**Recommendation:** Remove unused queries, select only necessary fields, paginate admin/history endpoints, use aggregate counts, and add measured indexes for due active URLs and latest snapshots. Align person-name uniqueness with a normalized or lowercased database index. Preserve a compact release/change event log if history is part of the product; deleting all but two page snapshots cannot fulfill README's complete-history claim.

The build produces about 1.05 MB of unminified JavaScript plus a 1.92 MB source map and 391 KB CSS before compression. Add a production build mode with minification and production environment defines. Split the 700-line dashboard into components and precompile Vue templates; this also makes a stricter CSP easier to adopt. Remove unused Vue build plugins/watch packages and unused Rails frameworks/Solid Queue configuration when their absence is verified. Make card toggles keyboard-accessible and add dialog focus management, labels, and Escape handling.

Public signup, unlimited monitoring/manual checks, alternate notification recipients, and one email for every blocked bot attempt can amplify resource/email usage. Client-supplied form timestamps are easy to bypass. Apply server-side throttles and account/source limits, aggregate bot-attempt notifications, validate recipient address format, and handle delivery failures. Alternate recipients should remain usable without ownership verification, as explicitly requested. Account authentication and admin authorization remain separate concerns.

## Suggested implementation sequence

1. Fix admin authorization, URL fetching isolation/validation, cross-user person assignment, and applicable dependency vulnerabilities.
2. Preserve successful state on failures; add atomic monitoring revisions, unique notification events, durable delivery, and asynchronous manual checks. Align email configuration and the supported deployment path.
3. Implement the confirmed release rule, fix timezone/dispatch/date-edit behavior, and reduce released URLs to once-daily checks.
4. Cache successful negative analyses, normalize secondary game comparisons, preserve useful page structure, support linked PDF content analysis, and add provider fixtures and regression tests.
5. Optimize shared source fetches, queries, browser capacity, frontend builds, and dashboard lifecycle based on measured usage.

## Remaining product choices

These do not block the findings above:

- What maximum pre-release alert delay and monthly AI budget should the adaptive polling policy target?
- Is open public signup intentional, or should account creation be limited? Alternate notification emails remain unverified either way.
- Is container deployment a real requirement, or can the unused Docker/Kamal/AWS alternatives be retired in favor of a single supported systemd deployment?
