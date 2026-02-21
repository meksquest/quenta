# syntax = docker/dockerfile:1

# Adjust NODE_VERSION as desired
ARG NODE_VERSION=23.11.0
FROM node:${NODE_VERSION}-slim AS base

LABEL fly_launch_runtime="SvelteKit"

# SvelteKit app lives here
WORKDIR /app

# Set production environment
ENV NODE_ENV="production"

# Install pnpm
ARG PNPM_VERSION=10.8.1
RUN npm install -g pnpm@$PNPM_VERSION

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install node modules
COPY .npmrc package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile --prod=false

# Copy application code
COPY . .

# Build application
RUN pnpm run build

# Remove development dependencies
RUN pnpm prune --prod

# Final stage for app image
FROM base

# Copy built application
COPY --from=build /app/build /app/build

# Copy node_modules
COPY --from=build /app/node_modules /app/node_modules

# Copy db migrations
COPY --from=build /app/migrations /app/migrations

# Copy important files into project root
COPY --from=build \
  /app/package.json \
  /app/docker-app-start.sh \
  /app/gmrc.cjs \
  /app/quenta-db.pem \
  /app/

# Start the server by default, this can be overwritten at runtime
EXPOSE 3000
CMD []
ENTRYPOINT [ "/app/docker-app-start.sh" ]
