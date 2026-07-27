#!/bin/bash
set -e

if ! sshd -t 2>/dev/null; then
  echo "The sshd configuration does not parse, so the daemon would refuse to start."
  echo "Find it with: sshd -t"
  exit 1
fi

SSHD=$(sshd -T 2>/dev/null)

for pair in "passwordauthentication no" "kbdinteractiveauthentication no"; do
  k=${pair% *}; want=${pair#* }
  got=$(awk -v k="$k" '$1==k{print $2; exit}' <<<"$SSHD")
  if [ "$got" != "$want" ]; then
    echo "sshd $k is '${got:-unset}', expected '$want'."
    echo "Set it in /etc/ssh/sshd_config.d/99-gateway.conf, then: sshd -t && systemctl restart ssh"
    exit 1
  fi
done

if ! awk '$1=="port"{print $2}' <<<"$SSHD" | grep -qx 2222; then
  echo "The sshd configuration does not include port 2222."
  echo "Add 'Port 2222' to the drop-in, keeping 'Port 22' until the new one is proven."
  exit 1
fi

# The whole point of this step: config resolved is not the same as socket listening.
if ! ss -tlnH | awk '{print $4}' | grep -qE '[:.]2222$'; then
  echo "sshd -T reports port 2222, but nothing is listening on it."
  echo
  echo "On Ubuntu 24.04 ssh is socket activated: systemd owns the port, not sshd, and"
  echo "'systemctl restart ssh' restarts the service without touching the socket."
  echo
  echo "  systemctl daemon-reload"
  echo "  systemctl restart ssh.socket"
  echo "  ss -tlnH | awk '{print \$4}' | grep 2222"
  exit 1
fi

# 22 should still be there. Closing it before proving 2222 is the lockout this teaches.
if ! ss -tlnH | awk '{print $4}' | grep -qE '[:.]22$'; then
  echo "Port 22 is no longer listening."
  echo "Keep it until you have opened and tested a session on 2222; that is what makes"
  echo "this recoverable. You can remove it afterwards on a real host."
  exit 1
fi

echo "sshd is key-only, and both 22 and 2222 are genuinely listening (not merely configured)."
exit 0
