FROM python:3.14-slim

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
