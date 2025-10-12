# Docker Hub Authentication Setup for CI

## Problem
GitHub Actions CI workflows were failing with Docker Hub authentication errors:
```
unauthorized: authentication required
```

This happens when GitHub Actions tries to pull Docker images (postgres:15, redis:7) but hits Docker Hub rate limits for unauthenticated requests.

## Solution Implemented

### 1. CI Workflow Changes
- Added Docker Hub credential environment variables to the workflow
- Added Docker login step before jobs that use Docker service containers
- Made authentication optional with `continue-on-error: true` so CI still works without credentials

### 2. Required GitHub Secrets Setup

To enable Docker Hub authentication, add these secrets to your repository:

1. Go to Settings → Secrets and variables → Actions
2. Add two new repository secrets:
   - `DOCKERHUB_USERNAME`: Your Docker Hub username
   - `DOCKERHUB_TOKEN`: Your Docker Hub access token (NOT your password)

### 3. How to Create Docker Hub Access Token

1. Log in to [Docker Hub](https://hub.docker.com)
2. Click on your username → Account Settings
3. Select "Security" → "New Access Token"
4. Give it a descriptive name like "GitHub Actions CI"
5. Copy the token and save it as `DOCKERHUB_TOKEN` secret in GitHub

## Benefits
- Avoids Docker Hub rate limits (100 pulls/6hr for anonymous vs 200 pulls/6hr for authenticated)
- CI runs more reliably without authentication failures
- Optional - CI still works without credentials, just with lower rate limits

## Files Modified
- `.github/workflows/ci.yml`: Added Docker authentication steps

## Testing
After adding the secrets, the CI will automatically use Docker Hub authentication for all Docker image pulls.