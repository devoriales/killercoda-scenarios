#!/bin/bash
set -e

CG=/sys/fs/cgroup/practice

if [ ! -d "$CG" ]; then
  echo "$CG does not exist."
  echo "Create it with: mkdir -p $CG"
  exit 1
fi

if [ ! -f "$CG/memory.max" ]; then
  echo "$CG/memory.max does not exist, so the memory controller was never delegated."
  echo "A parent has to hand a controller down before a child can use it:"
  echo "  echo '+memory' > /sys/fs/cgroup/cgroup.subtree_control"
  exit 1
fi

LIMIT=$(cat "$CG/memory.max")
if [ "$LIMIT" != "33554432" ]; then
  echo "memory.max is '$LIMIT', expected 33554432 (32 MiB)."
  echo "Set it with: echo 33554432 > $CG/memory.max"
  exit 1
fi

if [ ! -f "$CG/memory.events" ]; then
  echo "$CG/memory.events is missing, which should not happen once the controller is on."
  exit 1
fi

KILLS=$(awk '$1 == "oom_kill" {print $2}' "$CG/memory.events")
KILLS=${KILLS:-0}

if [ "$KILLS" -lt 1 ]; then
  echo "memory.events records oom_kill $KILLS, so nothing has been killed by this limit yet."
  echo "Setting a limit is not the same as seeing it enforced. Run something that exceeds it:"
  echo "  bash -c 'echo \$BASHPID > $CG/cgroup.procs"
  echo "           exec python3 -c \"b = bytearray(200 * 1024 * 1024)\"'"
  echo "Then check: cat $CG/memory.events"
  exit 1
fi

HITS=$(awk '$1 == "max" {print $2}' "$CG/memory.events")
echo "memory.max is 32 MiB, the kernel has OOM killed ${KILLS} process(es) in this cgroup, and the limit was reached ${HITS:-0} times."
exit 0
