#!/bin/bash
set -e

echo "Running scheduled hourly job..."
git checkout HEAD -- hourly_run.sh
