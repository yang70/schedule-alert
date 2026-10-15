CI.run do
  step "Setup", "bin/setup --skip-server"
  step "Tests", "bin/rails test"
  step "JavaScript tests", "npm test"
  step "Production assets", "NODE_ENV=production npm run build"
  step "Style: Ruby", "bin/rubocop"
  step "Security: Gem audit", "bin/bundler-audit check --update"
  step "Security: npm audit", "npm audit"
  step "Security: Brakeman", "bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error"
end
