# Ofelia Integration & Migration Guide

This document lists everything necessary to fully integrate **Ofelia** (Docker-native job scheduler) into the system, replacing ContainerPilot for job scheduling while using **Registrator** for Consul service discovery.

---

## 1. Overview of Architectural Changes

| Component | Current Setup (ContainerPilot) | Proposed Setup (Ofelia + Registrator) |
| :--- | :--- | :--- |
| **Scheduler** | In-container ContainerPilot process (`containerpilot.json5`) | Standalone **Ofelia** sidecar container (`mcuadros/ofelia`) |
| **Consul Discovery** | ContainerPilot direct registration | Host-level **Registrator** discovering `SERVICE_*` env vars |
| **App Image** | Custom Python image + ContainerPilot binary | Pure Python 3.13-slim image |
| **Trigger Mechanism** | Internal 1-hour interval timer | Ofelia executing `docker exec` via Docker Socket |

---

## 2. File-by-File Changes Required

### A. Update `docker-compose.yml`
1. Add `SERVICE_NAME` and `SERVICE_TAGS` for **Registrator**.
2. Add `ofelia.*` labels to the `weather` service.
3. Add the `ofelia` service definition.

```yaml
services:
  weather:
    build: .
    image: ghcr.io/matheussouza88/weather:latest
    container_name: weather-bot
    restart: unless-stopped
    environment:
      - CITY_NAME=${CITY_NAME:-Dublin, IE}
      - OPENWEATHER_API_KEY=${OPENWEATHER_API_KEY}
      - SERVICE_NAME=weather-bot
      - SERVICE_TAGS=automation,bot
    labels:
      - "ofelia.enabled=true"
      - "ofelia.job-exec.weather-check.schedule=@hourly"
      - "ofelia.job-exec.weather-check.command=/bin/bash hourly_run.sh"
    volumes:
      - ./:/app
      - ~/.gitconfig:/home/msilva/.gitconfig:ro
      - ~/.ssh:/home/msilva/.ssh:ro
    networks:
      - consul_consul

  ofelia:
    image: mcuadros/ofelia:latest
    container_name: ofelia
    restart: unless-stopped
    command: daemon --docker
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro

  watchtower:
    image: containrrr/watchtower:latest
    container_name: watchtower
    restart: unless-stopped
    environment:
      - DOCKER_API_VERSION=1.47
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ~/.docker/config.json:/config.json:ro
    command: --interval 300 --cleanup weather-bot
    depends_on:
      - weather

networks:
  consul_consul:
    external: true
```

---

### B. Update `Dockerfile`
Remove the multi-stage ContainerPilot download step and change the container `CMD` to keep the container running cleanly:

```dockerfile
FROM python:3.13-slim

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    unzip \
    openssh-client \
    && rm -rf /var/lib/apt/lists/* \
    && git config --system --add safe.directory /app

# Create user msilva
RUN groupadd -g 1000 msilva && \
    useradd -u 1000 -g msilva -m msilva

# Set permissions for /app
RUN mkdir -p /app && chown msilva:msilva /app

USER msilva
WORKDIR /app

# Copy application files
COPY --chown=msilva:msilva . ./

# Main container command (idle supervisor wait loop)
CMD ["sleep", "infinity"]
```

---

### C. Update `hourly_run.sh`
Remove the checkout reference to `containerpilot.json5` on line 15:

```diff
- git checkout HEAD -- hourly_run.sh containerpilot.json5
+ git checkout HEAD -- hourly_run.sh
```

---

### D. Delete Obsolete Files
Delete the old ContainerPilot configuration file:
* Remove `containerpilot.json5`

---

## 3. Step-by-Step Migration & Deployment Procedure

1. **Commit & Push Changes**:
   Create a Pull Request with the updated `docker-compose.yml`, `Dockerfile`, and `hourly_run.sh`, and delete `containerpilot.json5`.

2. **Deploy on Host (Raspberry Pi)**:
   ```bash
   # Pull latest image or rebuild locally
   docker compose build weather
   docker compose up -d
   ```

3. **Verify Ofelia Integration**:
   Check Ofelia logs to ensure it detected the `weather-check` job:
   ```bash
   docker logs ofelia
   ```
   *Expected log output:*
   `Scheduler started with 1 jobs.`

4. **Verify Manual Execution**:
   Test running the job on demand via Ofelia or `docker exec`:
   ```bash
   docker exec weather-bot /bin/bash hourly_run.sh
   ```

5. **Verify Consul Service Discovery**:
   Check that Registrator picked up `weather-bot`:
   ```bash
   curl -s http://localhost:8500/v1/catalog/service/weather-bot
   ```

---

## 4. Key Advantages of This Integration

1. **Simpler Application Image**: Eliminates custom ARM builds of ContainerPilot.
2. **Zero-Config Scheduling**: Uses Docker Labels Mode (`daemon --docker`), requiring no host config files.
3. **Decoupled Architecture**: Clean separation between application execution (`weather-bot`), scheduling (`ofelia`), discovery (`registrator`), and updates (`watchtower`).
