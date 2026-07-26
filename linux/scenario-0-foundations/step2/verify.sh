#!/bin/bash
set -e

WORKDIR=/root/investigation
LOG="$WORKDIR/access.log"
HARD="$WORKDIR/evidence-copy.log"

if [ ! -e "$HARD" ]; then
  echo "$HARD is missing. That hard link holds the only remaining copy of the data."
  echo "Restore it with: cp /root/course-data/access.log $HARD"
  exit 1
fi

if [ ! -e "$LOG" ]; then
  echo "$LOG does not exist yet."
  echo "Recreate it from the hard link: cd $WORKDIR && ln evidence-copy.log access.log"
  exit 1
fi

if [ -L "$WORKDIR/latest.log" ]; then
  echo "The dangling symlink $WORKDIR/latest.log is still present."
  echo "Remove it with: rm $WORKDIR/latest.log"
  exit 1
fi

# access.log and evidence-copy.log must be the SAME inode, not two separate copies.
INODE_LOG=$(stat -c %i "$LOG")
INODE_HARD=$(stat -c %i "$HARD")
if [ "$INODE_LOG" != "$INODE_HARD" ]; then
  echo "$LOG and $HARD have different inodes ($INODE_LOG and $INODE_HARD)."
  echo "They should be hard links to one file, not two copies."
  echo "Run: cd $WORKDIR && rm access.log && ln evidence-copy.log access.log"
  exit 1
fi

LINKS=$(stat -c %h "$LOG")
if [ "$LINKS" -lt 2 ]; then
  echo "The link count on $LOG is $LINKS, expected at least 2."
  echo "Run: cd $WORKDIR && ln evidence-copy.log access.log"
  exit 1
fi

LINES=$(wc -l < "$LOG")
if [ "$LINES" -ne 45 ]; then
  echo "$LOG has $LINES lines, expected 45."
  exit 1
fi

echo "Recovered. access.log and evidence-copy.log share inode $INODE_LOG with a link count of $LINKS, and the dangling symlink is gone."
exit 0
