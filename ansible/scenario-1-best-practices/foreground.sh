#!/bin/bash
clear 2>/dev/null || true
while [ ! -f /root/wait-ready.sh ]; do sleep 1; done
bash /root/wait-ready.sh
