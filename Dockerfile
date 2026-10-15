# syntax=docker/dockerfile:1
FROM node:22.23.2-bookworm-slim AS node
FROM ruby:3.3.10-slim AS base
WORKDIR /rails
RUN apt-get update -qq && apt-get install --no-install-recommends -y chromium curl libpq5 libyaml-0-2 && rm -rf /var/lib/apt/lists/* \
    && groupadd --gid 1000 rails && useradd --uid 1000 --gid 1000 --create-home rails
ENV BUNDLE_PATH=/usr/local/bundle CHROME_PATH=/usr/bin/chromium

FROM base AS development
COPY --from=node /usr/local/ /usr/local/
RUN apt-get update -qq && apt-get install --no-install-recommends -y build-essential git libpq-dev libyaml-dev && rm -rf /var/lib/apt/lists/*
COPY Gemfile Gemfile.lock ./
RUN bundle install
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN chown -R rails:rails /rails /usr/local/bundle
USER rails
EXPOSE 3000
CMD ["./bin/dev"]

FROM development AS build
ENV RAILS_ENV=production NODE_ENV=production BUNDLE_WITHOUT=development:test BUNDLE_DEPLOYMENT=1
RUN SECRET_KEY_BASE_DUMMY=1 bundle exec rails assets:precompile && bundle clean --force && rm -rf node_modules

FROM base AS production
ENV RAILS_ENV=production BUNDLE_WITHOUT=development:test BUNDLE_DEPLOYMENT=1 PUMA_BIND=tcp://0.0.0.0:3000
COPY --chown=rails:rails --from=build /usr/local/bundle /usr/local/bundle
COPY --chown=rails:rails --from=build /rails /rails
USER rails
EXPOSE 3000
ENTRYPOINT ["./bin/docker-entrypoint"]
CMD ["bundle", "exec", "puma", "-C", "config/puma.rb"]
