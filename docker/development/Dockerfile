# Development image for docker compose (Rails web + Sidekiq).
# Kept under docker/development/ so root .dockerignore `/Dockerfile*` does not exclude it from build context.
ARG RUBY_VERSION=3.4.4
FROM docker.io/library/ruby:${RUBY_VERSION}-slim

RUN apt-get update -qq && apt-get install --no-install-recommends -y \
    build-essential curl git libpq-dev libyaml-dev pkg-config postgresql-client \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

WORKDIR /rails

ENV RAILS_ENV=development \
    BUNDLE_PATH=/usr/local/bundle \
    BUNDLE_JOBS=4

COPY Gemfile Gemfile.lock ./
RUN bundle install

COPY . .

EXPOSE 3000

CMD [ "./bin/rails", "server", "-b", "0.0.0.0", "-p", "3000" ]
