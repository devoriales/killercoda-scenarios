#!/bin/bash
set -e

# Everything here runs podman AS appops. A container started by root is a different
# thing entirely and lives in a different store, so asking root's podman would give
# the wrong answer.
as_appops() { su - appops -c "$1" 2>/dev/null; }

if ! getent passwd appops >/dev/null; then
  echo "The appops account is missing. It should have been created for you."
  exit 1
fi

STATE=$(as_appops "podman inspect --format '{{.State.Status}}' app" || true)
if [ "$STATE" != "running" ]; then
  echo "appops has no running container named 'app' (status: '${STATE:-not found}')."
  echo "Start it with:"
  echo "  su - appops -c 'podman run -d --name app --memory=64m -p 8080:80 docker.io/library/nginx:alpine'"
  exit 1
fi

# It must actually serve.
CODE=$(curl -s --max-time 10 -o /dev/null -w '%{http_code}' http://127.0.0.1:8080/ || true)
if [ "$CODE" != "200" ]; then
  echo "http://127.0.0.1:8080/ returned '${CODE}', expected 200."
  echo "Check the port mapping with: su - appops -c 'podman ps'"
  echo "The container needs -p 8080:80 to publish port 80 on the host's 8080."
  exit 1
fi

PID=$(as_appops "podman inspect --format '{{.State.Pid}}' app" || true)
if [ -z "$PID" ] || [ "$PID" = "0" ]; then
  echo "Could not determine the container's host PID."
  exit 1
fi

# The whole point of the step: root in the container is not root on the host.
RUNAS=$(ps -o user= -p "$PID" 2>/dev/null | tr -d ' ')
if [ -z "$RUNAS" ]; then
  echo "No host process found for PID $PID."
  exit 1
fi

if [ "$RUNAS" = "root" ]; then
  echo "The container's host process is running as root, so this is not rootless."
  echo "It was most likely started by root rather than by appops. Remove it and retry:"
  echo "  podman rm -f app 2>/dev/null"
  echo "  su - appops -c 'podman run -d --name app --memory=64m -p 8080:80 docker.io/library/nginx:alpine'"
  exit 1
fi

# And confirm it really is in its own PID namespace, not sharing the host's.
HOST_NS=$(readlink /proc/self/ns/pid)
CONT_NS=$(readlink "/proc/$PID/ns/pid" 2>/dev/null || true)
if [ -n "$CONT_NS" ] && [ "$CONT_NS" = "$HOST_NS" ]; then
  echo "The container shares the host's PID namespace ($HOST_NS), so it is not isolated."
  echo "Was it started with --pid=host?"
  exit 1
fi

echo "Container 'app' is running rootless as host user '${RUNAS}' (PID ${PID}), serving 200 on port 8080, in its own PID namespace."
exit 0
