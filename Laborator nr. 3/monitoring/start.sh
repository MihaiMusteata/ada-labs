#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Starting Lab 3 monitoring system..."

if ! command -v docker >/dev/null 2>&1; then
  echo "Error: Docker is not installed or not available in PATH."
  exit 1
fi

if ! docker compose version >/dev/null 2>&1; then
  echo "Error: Docker Compose is not available."
  exit 1
fi

load_image_if_missing() {
  local image_name="$1"
  local image_tar="$2"

  if docker image inspect "$image_name" >/dev/null 2>&1; then
    echo "Image already exists: $image_name"
  else
    echo "Image missing: $image_name"

    if [ ! -f "$image_tar" ]; then
      echo "Error: image archive not found: $image_tar"
      exit 1
    fi

    echo "Loading image from $image_tar..."
    docker load -i "$image_tar"
  fi
}

load_image_if_missing "archive-api:lab3" "images/archive-api-lab3.tar"
load_image_if_missing "archive-client:lab3" "images/archive-client-lab3.tar"

echo "Starting containers..."
docker compose up -d

echo ""
echo "System started successfully."
echo ""
echo "Useful links:"
echo "  Aplicație web:       http://localhost:3232"
echo "  Prometheus:          http://localhost:9090"
echo "  Prometheus targets:  http://localhost:9090/targets"
echo "  Grafana:             http://localhost:3000"
echo "  Node Exporter:       http://localhost:9100/metrics"
echo ""
echo "Grafana login:"
echo "  username: admin"
echo "  password: admin"
echo ""
echo "Container status:"
docker compose ps
