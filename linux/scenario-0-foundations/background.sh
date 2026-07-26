#!/bin/bash
# background.sh — runs silently before the student arrives.
# Students never see this script or its output.
#
# Setup is deliberately instant: this only writes data files, so no foreground.sh
# progress display is needed. Every command is safe to run twice.
#
# `set -uo pipefail` but NOT `set -e`: one failing line must never abort setup and
# leave the student with a half-built lab.
set -uo pipefail

mkdir -p /var/log/killercoda
mkdir -p /root/course-data

# Step 1 uses `file` to show that Linux identifies content rather than trusting an
# extension. Most Ubuntu images ship it, but the minimal ones do not, and a missing
# binary there means the student's first step ends in "command not found". Guarded so
# it costs nothing when already present and cannot abort setup when the network is slow.
if ! command -v file >/dev/null 2>&1; then
  echo "[background] file(1) missing, installing." >> /var/log/killercoda/background.log
  { apt-get update -qq && apt-get install -y -qq file; } \
    >> /var/log/killercoda/background.log 2>&1
fi

# The access log the student investigates in step 4. Realistic nginx combined format.
# 45 requests. One client (203.0.113.42) is a vulnerability scanner: 12 requests,
# 11 of them 404, walking a list of credential and admin paths.
cat > /root/course-data/access.log <<'ACCESSLOG'
198.51.100.17 - - [14/Mar/2026:08:12:03 +0000] "GET /index.html HTTP/1.1" 200 5320 "-" "Mozilla/5.0 (X11; Linux x86_64)"
198.51.100.17 - - [14/Mar/2026:08:12:04 +0000] "GET /assets/app.css HTTP/1.1" 200 18244 "https://shop.example.net/index.html" "Mozilla/5.0 (X11; Linux x86_64)"
198.51.100.17 - - [14/Mar/2026:08:12:04 +0000] "GET /assets/app.js HTTP/1.1" 200 96117 "https://shop.example.net/index.html" "Mozilla/5.0 (X11; Linux x86_64)"
192.0.2.88 - - [14/Mar/2026:08:13:41 +0000] "GET /products HTTP/1.1" 200 24810 "-" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
192.0.2.88 - - [14/Mar/2026:08:13:47 +0000] "GET /products/hydration-pack HTTP/1.1" 200 31502 "https://shop.example.net/products" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
203.0.113.42 - - [14/Mar/2026:08:14:02 +0000] "GET /wp-login.php HTTP/1.1" 404 162 "-" "python-requests/2.31.0"
203.0.113.42 - - [14/Mar/2026:08:14:02 +0000] "GET /wp-admin/ HTTP/1.1" 404 162 "-" "python-requests/2.31.0"
203.0.113.42 - - [14/Mar/2026:08:14:03 +0000] "GET /.env HTTP/1.1" 404 162 "-" "python-requests/2.31.0"
203.0.113.42 - - [14/Mar/2026:08:14:03 +0000] "GET /.git/config HTTP/1.1" 404 162 "-" "python-requests/2.31.0"
203.0.113.42 - - [14/Mar/2026:08:14:04 +0000] "GET /phpmyadmin/ HTTP/1.1" 404 162 "-" "python-requests/2.31.0"
198.51.100.203 - - [14/Mar/2026:08:15:19 +0000] "GET /index.html HTTP/1.1" 200 5320 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
198.51.100.203 - - [14/Mar/2026:08:15:26 +0000] "POST /api/cart HTTP/1.1" 201 89 "https://shop.example.net/products" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
198.51.100.203 - - [14/Mar/2026:08:15:58 +0000] "POST /api/checkout HTTP/1.1" 500 412 "https://shop.example.net/cart" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
198.51.100.203 - - [14/Mar/2026:08:16:11 +0000] "POST /api/checkout HTTP/1.1" 500 412 "https://shop.example.net/cart" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
203.0.113.42 - - [14/Mar/2026:08:16:30 +0000] "GET /config.json HTTP/1.1" 404 162 "-" "python-requests/2.31.0"
203.0.113.42 - - [14/Mar/2026:08:16:31 +0000] "GET /backup.sql HTTP/1.1" 404 162 "-" "python-requests/2.31.0"
192.0.2.150 - - [14/Mar/2026:08:17:08 +0000] "GET / HTTP/1.1" 301 178 "-" "curl/8.5.0"
192.0.2.150 - - [14/Mar/2026:08:17:08 +0000] "GET /index.html HTTP/1.1" 200 5320 "-" "curl/8.5.0"
198.51.100.17 - - [14/Mar/2026:08:18:44 +0000] "GET /products HTTP/1.1" 200 24810 "https://shop.example.net/index.html" "Mozilla/5.0 (X11; Linux x86_64)"
198.51.100.17 - - [14/Mar/2026:08:19:02 +0000] "POST /api/cart HTTP/1.1" 201 89 "https://shop.example.net/products" "Mozilla/5.0 (X11; Linux x86_64)"
198.51.100.17 - - [14/Mar/2026:08:19:35 +0000] "POST /api/checkout HTTP/1.1" 500 412 "https://shop.example.net/cart" "Mozilla/5.0 (X11; Linux x86_64)"
192.0.2.88 - - [14/Mar/2026:08:20:12 +0000] "GET /assets/logo.svg HTTP/1.1" 200 4402 "https://shop.example.net/products" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
192.0.2.88 - - [14/Mar/2026:08:20:51 +0000] "GET /products/trail-runner HTTP/1.1" 200 29984 "https://shop.example.net/products" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
203.0.113.42 - - [14/Mar/2026:08:21:17 +0000] "GET /admin HTTP/1.1" 404 162 "-" "python-requests/2.31.0"
203.0.113.42 - - [14/Mar/2026:08:21:18 +0000] "GET /server-status HTTP/1.1" 403 199 "-" "python-requests/2.31.0"
198.51.100.94 - - [14/Mar/2026:08:22:40 +0000] "GET /index.html HTTP/1.1" 200 5320 "-" "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4)"
198.51.100.94 - - [14/Mar/2026:08:22:43 +0000] "GET /assets/app.css HTTP/1.1" 304 0 "https://shop.example.net/index.html" "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4)"
198.51.100.94 - - [14/Mar/2026:08:23:15 +0000] "GET /products HTTP/1.1" 200 24810 "https://shop.example.net/index.html" "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4)"
192.0.2.150 - - [14/Mar/2026:08:24:01 +0000] "GET /api/health HTTP/1.1" 200 27 "-" "curl/8.5.0"
198.51.100.203 - - [14/Mar/2026:08:25:33 +0000] "POST /api/checkout HTTP/1.1" 201 305 "https://shop.example.net/cart" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
198.51.100.203 - - [14/Mar/2026:08:25:34 +0000] "GET /orders/48812 HTTP/1.1" 200 7719 "https://shop.example.net/cart" "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
192.0.2.88 - - [14/Mar/2026:08:26:59 +0000] "POST /api/cart HTTP/1.1" 201 89 "https://shop.example.net/products/trail-runner" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
203.0.113.42 - - [14/Mar/2026:08:27:44 +0000] "GET /.aws/credentials HTTP/1.1" 404 162 "-" "python-requests/2.31.0"
203.0.113.42 - - [14/Mar/2026:08:27:45 +0000] "GET /.ssh/id_rsa HTTP/1.1" 404 162 "-" "python-requests/2.31.0"
198.51.100.94 - - [14/Mar/2026:08:28:20 +0000] "GET /products/hydration-pack HTTP/1.1" 200 31502 "https://shop.example.net/products" "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4)"
192.0.2.211 - - [14/Mar/2026:08:29:07 +0000] "GET /index.html HTTP/1.1" 200 5320 "-" "Mozilla/5.0 (X11; Linux x86_64)"
192.0.2.211 - - [14/Mar/2026:08:29:55 +0000] "GET /search?q=running+shoes HTTP/1.1" 200 18830 "https://shop.example.net/index.html" "Mozilla/5.0 (X11; Linux x86_64)"
192.0.2.211 - - [14/Mar/2026:08:30:22 +0000] "GET /search?q=%27+OR+1%3D1 HTTP/1.1" 400 226 "https://shop.example.net/index.html" "Mozilla/5.0 (X11; Linux x86_64)"
198.51.100.17 - - [14/Mar/2026:08:31:40 +0000] "POST /api/checkout HTTP/1.1" 201 305 "https://shop.example.net/cart" "Mozilla/5.0 (X11; Linux x86_64)"
192.0.2.150 - - [14/Mar/2026:08:32:00 +0000] "GET /api/health HTTP/1.1" 200 27 "-" "curl/8.5.0"
198.51.100.94 - - [14/Mar/2026:08:33:18 +0000] "POST /api/cart HTTP/1.1" 201 89 "https://shop.example.net/products/hydration-pack" "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4)"
203.0.113.42 - - [14/Mar/2026:08:34:02 +0000] "GET /vendor/phpunit/phpunit/phpunit.xml HTTP/1.1" 404 162 "-" "python-requests/2.31.0"
192.0.2.88 - - [14/Mar/2026:08:35:29 +0000] "POST /api/checkout HTTP/1.1" 500 412 "https://shop.example.net/cart" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
192.0.2.150 - - [14/Mar/2026:08:36:00 +0000] "GET /api/health HTTP/1.1" 200 27 "-" "curl/8.5.0"
198.51.100.94 - - [14/Mar/2026:08:37:51 +0000] "GET /orders/48815 HTTP/1.1" 200 7719 "https://shop.example.net/products" "Mozilla/5.0 (iPhone; CPU iPhone OS 17_4)"
ACCESSLOG

# A small config file used in step 3 for reading metadata.
cat > /root/course-data/app.conf <<'APPCONF'
listen_port = 8080
worker_processes = 4
log_level = info
APPCONF

chmod 0644 /root/course-data/access.log
chmod 0640 /root/course-data/app.conf

echo "[background] Ready. Data in /root/course-data." >> /var/log/killercoda/background.log
