#!/bin/bash
set -e

ANSWER=/root/answers/pidns.txt

if [ ! -f "$ANSWER" ]; then
  echo "$ANSWER does not exist."
  echo "Create it with:"
  echo "  unshare --pid --fork --mount-proc ps -e --no-headers | wc -l > $ANSWER"
  exit 1
fi

GOT=$(tr -dc '0-9' < "$ANSWER")

if [ -z "$GOT" ]; then
  echo "$ANSWER contains no number."
  echo "It should hold a bare count, nothing else."
  exit 1
fi

# Inside a fresh PID namespace with its own /proc, the only visible process is the one
# doing the looking. Accept 1 or 2: whether `ps` sees just itself or also a short-lived
# parent depends on how the command is invoked, and both prove the point.
if [ "$GOT" -gt 2 ]; then
  echo "$ANSWER says $GOT, which is too many to have come from inside a new PID namespace."
  echo "That looks like the host's process list. The usual cause is a missing --mount-proc,"
  echo "which leaves ps reading the host's /proc through the new namespace."
  echo "Try: unshare --pid --fork --mount-proc ps -e --no-headers | wc -l"
  exit 1
fi

if [ "$GOT" -lt 1 ]; then
  echo "$ANSWER says $GOT. A namespace always contains at least the process doing the looking."
  exit 1
fi

# Confirm the student can actually create namespaces here, rather than only that a
# plausible number reached a file.
HOST_NS=$(readlink /proc/self/ns/pid)
NEW_NS=$(unshare --pid --fork readlink /proc/self/ns/pid 2>/dev/null || true)

if [ -z "$NEW_NS" ]; then
  echo "Could not create a PID namespace on this host, which the rest of the lab needs."
  echo "Check with: unshare --pid --fork readlink /proc/self/ns/pid"
  exit 1
fi

if [ "$HOST_NS" = "$NEW_NS" ]; then
  echo "unshare returned the same PID namespace as the host ($HOST_NS)."
  echo "A new namespace should have a different inode number."
  exit 1
fi

echo "Recorded $GOT process visible inside a new PID namespace, and namespaces are working here ($HOST_NS on the host, $NEW_NS when unshared)."
exit 0
