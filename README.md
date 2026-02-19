# Pocket ID on Fly.io with Litestream

This repository contains the configuration to deploy [Pocket ID](https://github.com/11notes/pocket-id) on [Fly.io](https://fly.io), using [Litestream](https://litestream.io) for SQLite replication to [Tigris](https://fly.io/docs/reference/tigris/) (Fly.io's S3-compatible object storage).

## Overview

The setup builds a custom Docker image that bundles:
- **Pocket ID**: A simple and lightweight OIDC provider.
- **Litestream**: A tool for replicating SQLite databases to S3.

The application entrypoint is Litestream, which:
1. Restores the database from S3 (if it exists).
2. Starts replicating changes to the S3 bucket.
3. Launches Pocket ID as a subprocess.

This ensures your SQLite database is backed up and can be restored if the Fly machine is restarted or moved.

## Prerequisites

- [Fly.io](https://fly.io) account and CLI installed.
- S3-compatible storage bucket (Fly Tigris, AWS S3, Cloudflare R2, MinIO).
- GitHub repository for CI/CD (optional, but configured in `.github`).

## Configuration

### Environment Variables

The following environment variables are configured in `fly.yaml`:

| Variable | Description |
|----------|-------------|
| `APP_URL` | The public URL of your Pocket ID instance. |
| `DB_CONNECTION_STRING` | Path to the SQLite database file (`/usr/local/var/data/pocket-id.db`). |
| `FILE_BACKEND` | Set to `s3` to use S3 for file storage (if applicable). |

### Tigris Storage (S3)

With Fly.io, you can use [Tigris](https://fly.io/docs/reference/tigris/) for S3-compatible object storage. This simplifies the setup significantly.

1.  **Create a Tigris bucket**:
    ```bash
    fly storage create
    ```
    This will automatically set the following secrets on your app:
    - `AWS_ACCESS_KEY_ID`
    - `AWS_SECRET_ACCESS_KEY`
    - `AWS_ENDPOINT_URL_S3`
    - `AWS_REGION`
    - `BUCKET_NAME`

2.  **Verify configuration**:
    Ensure your `fly.yaml` environment variables (or secrets) map correctly if the names differ, but by default, Litestream and standard AWS SDKs will pick up `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, and `AWS_ENDPOINT_URL_S3`.

    *Note: The `etc/litestream.yml` in this image expects `BUCKET_NAME` to be set.*

## Deployment

### Manual Deployment

1. **Launch the app** (first time only):
   ```bash
   fly launch --no-deploy
   ```
   *Note: This will generate a `fly.toml` if one doesn't exist, but you should use the provided `fly.yaml` as a base.*

2. **Create the volume**:
   ```bash
   fly volumes create data --size 1
   ```

3. **Set up storage**:
   Run `fly storage create` to provision a Tigris bucket and automatically set the necessary secrets (`AWS_ACCESS_KEY_ID`, etc.).

4. **Deploy**:
   ```bash
   fly deploy
   ```

### CI/CD

The repository includes a GitHub Action `.github/workflows/fly-deploy.yml` that automatically deploys changes pushed to the `master` branch.

To enable this:
1. Get a Fly API token: `fly tokens create deploy -x 999999h`
2. Add it to your GitHub Repository Secrets as `FLY_API_TOKEN`.

## Dockerfile Details

The `Dockerfile` performs a multi-stage build:
1. **Base Images**: Uses `11notes/distroless`, `11notes/util`, `litestream/litestream`, and `11notes/pocket-id`.
2. **File System**: Sets up the directory structure and copies binaries.
3. **Runtime**: Configures the environment, exposes port `1411`, sets up the healthcheck, and defines the entrypoint as `litestream replicate`.

