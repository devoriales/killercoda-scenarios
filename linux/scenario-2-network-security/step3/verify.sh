#!/bin/bash
set -e

if ! nft list table inet filter >/dev/null 2>&1; then
  echo "There is no 'inet filter' table loaded."
  echo "Write the ruleset to a file, check it, then apply it:"
  echo "  nft -c -f /root/firewall.nft && nft -f /root/firewall.nft"
  exit 1
fi

RULESET=$(nft list table inet filter)

# 1. Default deny. An allow-list firewall is the only shape worth having.
if ! echo "$RULESET" | grep -qE 'chain input \{'; then
  echo "The filter table has no input chain."
  exit 1
fi
if ! echo "$RULESET" | sed -n '/chain input/,/}/p' | grep -qE 'policy drop'; then
  echo "The input chain policy is not 'drop'."
  echo "A default-accept firewall only blocks what you already thought of."
  exit 1
fi

# 2. The rule whose absence is the whole point of this step.
if ! echo "$RULESET" | grep -qE 'ct state.*established'; then
  echo "No 'ct state established,related accept' rule in the input chain."
  echo "Without it, replies to this host's own outbound connections are dropped:"
  echo "DNS hangs and apt stalls, while inbound SSH keeps working."
  exit 1
fi

# 3. Loopback, or the local resolver stub breaks.
if ! echo "$RULESET" | grep -qE 'iif(name)? "?lo"? accept'; then
  echo "No 'iif lo accept' rule."
  echo "Plenty of software talks to itself over loopback, including systemd-resolved."
  exit 1
fi

# 4. The two ports this host actually offers.
if ! echo "$RULESET" | grep -qE 'tcp dport (22|\{[^}]*22[^}]*\})'; then
  echo "Port 22 is not accepted. That is how you lose a remote machine."
  exit 1
fi
if ! echo "$RULESET" | grep -qE 'tcp dport (9095|\{[^}]*9095[^}]*\})'; then
  echo "Port 9095 is not accepted, so the metrics endpoint you fixed in step 1 is"
  echo "now unreachable again, this time because of the firewall."
  exit 1
fi

# 5. Prove it behaves, rather than trusting that it reads correctly.
if ! curl -s --max-time 5 -o /dev/null http://127.0.0.1:9095/; then
  echo "The metrics endpoint no longer answers on loopback with the ruleset loaded."
  echo "Check that 'iif lo accept' is present and above any drop."
  exit 1
fi

if ! timeout 8 getent hosts archive.ubuntu.com >/dev/null 2>&1; then
  echo "Outbound DNS is not working with this ruleset loaded."
  echo "That is the signature of a missing connection tracking rule: the query leaves,"
  echo "and the reply is dropped on the way back in."
  echo "Add as the FIRST rule of the input chain:  ct state established,related accept"
  exit 1
fi

echo "Default-deny ruleset loaded, connection tracking present, ssh and metrics reachable, outbound DNS still working."
exit 0
