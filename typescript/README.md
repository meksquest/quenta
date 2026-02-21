# Quenta

## Configure Environment Variables

```
cp .env.example .env
```

## Start Database

```bash
docker compose up
```

(if `docker compose` doesn't work, try `docker-compose`)

## Initial Database Setup

Create the `quenta` database:

```
pnpm run graphile-migrate reset --erase
```

## Docker

### Build Docker Image Locally

```sh
docker build -t quenta/app .
```

### Run Docker Image Locally

```sh
docker run --rm --name quenta-app quenta/app
```

## Database Connection

We are using crunchybase

Add `?ssl=true&sslrootcert=/app/crunchydb.pem` to the end of the connection
string to ensure that SSL works as expected.
