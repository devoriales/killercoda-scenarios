#!/bin/bash
clear 2>/dev/null || true
while [ ! -f /root/progress.sh ]; do sleep 1; done
bash /root/progress.sh
