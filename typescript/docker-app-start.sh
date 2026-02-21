#!/usr/bin/env sh

set -eux

# run database migrations
pnpm exec graphile-migrate migrate --config ./gmrc.cjs

# start the application
exec pnpm run start
