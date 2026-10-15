#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -f .env.production ]]; then
  echo 'Missing .env.production. See DEPLOYMENT.md.' >&2
  exit 1
fi
set -a
source .env.production
set +a
export RAILS_ENV=production NODE_ENV=production
if [[ -x "$HOME/.rbenv/bin/rbenv" ]]; then
  export PATH="$HOME/.rbenv/bin:$PATH"
  eval "$(rbenv init -)"
fi
if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
  source "$HOME/.nvm/nvm.sh"
  nvm use
fi
[[ $(node -p 'process.versions.node.split(".")[0]') == 22 ]] || { echo 'Node 22 is required.' >&2; exit 1; }
[[ -z $(git status --porcelain --untracked-files=no) ]] || { echo 'Commit or restore tracked changes before deploying.' >&2; exit 1; }
previous_revision=$(git rev-parse HEAD)
trap 'echo "Deployment failed. Previous commit: $previous_revision. Check service status and DEPLOYMENT.md before retrying." >&2' ERR

git pull --ff-only origin "${DEPLOY_BRANCH:-main}"
bundle config set --local without 'development test'
bundle config set --local deployment true
bundle install
npm ci
bundle exec rails assets:precompile
sudo systemctl stop tourneyping-worker
bundle exec rails db:migrate
sudo cp config/systemd/tourneyping-*.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl restart tourneyping-web tourneyping-worker
for attempt in {1..20}; do
  if curl --fail --silent --output /dev/null -H "Host: ${APP_HOST}" http://127.0.0.1:3000/up; then
    sudo systemctl is-active --quiet tourneyping-web tourneyping-worker
    echo "Deployment healthy. Previous commit: $previous_revision"
    exit 0
  fi
  sleep 2
done
echo 'Application health check failed.' >&2
exit 1
