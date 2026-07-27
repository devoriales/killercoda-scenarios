#!/bin/bash
set -e

ANSWER=/root/answers/pkg.txt

if [ ! -f "$ANSWER" ]; then
  echo "$ANSWER does not exist."
  echo "Create it with: dpkg -S \"\$(which nft)\" | cut -d: -f1 > $ANSWER"
  exit 1
fi

# Tolerate trailing whitespace and a stray newline; reject anything else.
GOT=$(tr -d '[:space:]' < "$ANSWER")

if [ -z "$GOT" ]; then
  echo "$ANSWER is empty."
  echo "Write the package name into it: dpkg -S \"\$(which nft)\" | cut -d: -f1 > $ANSWER"
  exit 1
fi

if [ "$GOT" != "nftables" ]; then
  echo "$ANSWER contains '$GOT', which is not the package that owns the nft binary."
  echo "Find it with: dpkg -S \"\$(which nft)\""
  echo "Note that dpkg -S prints 'package: /path', so keep only the part before the colon."
  exit 1
fi

if ! command -v apt-mark >/dev/null 2>&1; then
  echo "apt-mark is not available on this machine, which should not happen on Ubuntu."
  exit 1
fi

if ! apt-mark showhold 2>/dev/null | grep -qx nftables; then
  echo "nftables is not on hold."
  echo "Current holds: $(apt-mark showhold 2>/dev/null | tr '\n' ' ' | sed 's/ $//')"
  echo "Set it with: apt-mark hold nftables"
  exit 1
fi

echo "nftables identified as the owning package and placed on hold, so the next upgrade will leave it alone."
exit 0
