# Ofelia Integration & Setup Guide

A generic guideline for integrating **Ofelia** (a Docker-native job scheduler) into any containerized application or service. 

Ofelia operates as a lightweight sidecar container that reads Docker container labels to schedule and execute commands inside target containers via the Docker Socket.

---

## 1. Architecture Overview

| Component | Function |
| :--- | :--- |
| **Application Container** | Main service container running your application. Configured with `ofelia.*` labels. |
| **Ofelia Sidecar** | Container running `mcuadros/ofelia` in `--docker` daemon mode, monitoring the Docker API socket to trigger jobs on scheduled containers. |
| **Watchtower (Optional)** | Sidecar container for managing container updates. |
| **Registrator (Optional)** | Container for discovery registration with Consul using `SERVICE_*` environment variables. |

---

## 2. Integration Steps

### Step 1: Update `docker-compose.yml`

Add the `ofelia` service definition and attach `ofelia.*` labels to your application service.

```yaml
services:
  app:
    build: .
    image: ghcr.io/<your-github-user>/<your-repo-name>:<version-tag>
    container_name: app
    restart: unless-stopped
    environment:
      - SERVICE_NAME=app
      - SERVICE_TAGS=automation
    labels:
      - "ofelia.enabled=true"
      - "ofelia.job-exec.<job-name>.schedule=@hourly"
      - "ofelia.job-exec.<job-name>.command=/bin/bash /app/run_job.sh"
    volumes:
      - ./:/app
    networks:
      - custom_network

  ofelia:
    image: mcuadros/ofelia:v0.3.9
    container_name: ofelia
    restart: unless-stopped
    command: daemon --docker
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

  watchtower:
    image: containrrr/watchtower:1.7.1
    container_name: watchtower
    restart: unless-stopped
    environment:
      - DOCKER_API_VERSION=1.47
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ~/.docker/config.json:/config.json:ro
    command: --interval 300 --cleanup app
    depends_on:
      - app

networks:
  custom_network:
    external: true
```

#### Ofelia Label Reference
- `ofelia.enabled=true`: Enables Ofelia scheduler monitoring for the container.
- `ofelia.job-exec.<job-name>.schedule`: Cron expression or shortcut (`@hourly`, `@daily`, `@every 1h`, `0 0 * * *`).
- `ofelia.job-exec.<job-name>.command`: The command to execute inside the container.

---

### Step 2: Configure Application `Dockerfile`

Ensure your container stays active so Ofelia can execute scheduled commands against it:

```dockerfile
FROM python:3.13-slim

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy application code
COPY . .

# Keep container alive in idle supervisor mode
CMD ["sleep", "infinity"]
```

---

### Step 3: Create Scheduled Job Script (`run_job.sh`)

Create the script referenced in the Ofelia labels:

```bash
#!/bin/bash
set -e

echo "[$(date)] Running scheduled job execution..."
# Add your application logic or script execution here
```

Ensure the script has executable permissions:
```bash
chmod +x run_job.sh
```

---

## 3. Verification & Operational Testing

1. **Start the Stack**:
   ```bash
   docker compose up -d
   ```

2. **Verify Ofelia Job Detection**:
   Check Ofelia logs to verify it discovered the container labels and registered the job:
   ```bash
   docker logs ofelia
   ```
   *Expected output:* `Scheduler started with 1 jobs.`

3. **Test Manual Execution**:
   Run the job script manually to verify behavior inside the container:
   ```bash
   docker exec app /bin/bash /app/run_job.sh
   ```

---

## 4. Security & Best Practices

- **Secrets Management**: Never commit API keys, tokens, or credentials to version control. Pass credentials via environment variables (`.env` file or secrets manager).
- **Pinned Image Tags**: Use explicit image version tags (e.g. `v0.3.9`, `1.7.1`) instead of `:latest` to maintain deterministic deployments.
- **Automated Updates**: Configure Dependabot (`.github/dependabot.yml`) to automatically check for base image and docker-compose version updates.
- **Least Privilege**: Mount `/var/run/docker.sock` as read-only (`:ro`) in the `ofelia` service.
