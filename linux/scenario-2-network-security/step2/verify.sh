#!/bin/bash
set -e

# sshd -T is the whole point of the step: it reports what the RUNNING daemon resolved,
# not what some file says. A student who edited a file without restarting fails here,
# which is exactly the lesson.
if ! sshd -t 2>/dev/null; then
  echo "The sshd configuration does not parse. The daemon would refuse to start."
  echo "Find the fault with: sshd -t"
  exit 1
fi

EFFECTIVE=$(sshd -T 2>/dev/null)

check() {
  local key="$1" want="$2"
  local got
  got=$(echo "$EFFECTIVE" | awk -v k="$key" '$1 == k {print $2; exit}')
  if [ "$got" != "$want" ]; then
    echo "$key is '${got:-unset}', expected '$want'."
    return 1
  fi
  return 0
}

FAILED=0
check passwordauthentication         no || FAILED=1
check kbdinteractiveauthentication   no || FAILED=1
check maxauthtries                   3  || FAILED=1

ROOTLOGIN=$(echo "$EFFECTIVE" | awk '$1 == "permitrootlogin" {print $2; exit}')
if [ "$ROOTLOGIN" = "yes" ]; then
  echo "permitrootlogin is 'yes', which permits password login as root."
  FAILED=1
fi

if [ "$FAILED" -ne 0 ]; then
  echo
  echo "Those are the values the RUNNING daemon has resolved, so a file you edited but"
  echo "did not apply will not show up here. After writing the drop-in, run:"
  echo "  sshd -t && systemctl restart ssh"
  exit 1
fi

# The settings should come from a drop-in rather than edits to the packaged file.
if [ ! -f /etc/ssh/sshd_config.d/99-hardening.conf ]; then
  echo "The values are right, but there is no /etc/ssh/sshd_config.d/99-hardening.conf."
  echo "Put hardening in a drop-in so a package upgrade cannot conflict with it."
  exit 1
fi

echo "sshd is enforcing key-only authentication, three auth tries, and no root password login."
exit 0
