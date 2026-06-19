# Step 6 — Handlers: Reacting to Change

## What is a handler?

A **handler** is a task that runs only when notified by another task, and only when that notifying task reported `changed`. Handlers solve a common production problem precisely: restart nginx only when its configuration actually changed — not every time the playbook runs.

Handlers have three important behaviours that set them apart from normal tasks:

**Notification-gated.** A task fires a notification with `notify: <handler name>`. If the task reports `ok` (nothing changed), the notification is not sent and the handler does not run.

**Deduplicated.** If ten tasks all notify the same handler in the same play, the handler runs **once** — at the end of the play, not ten times. This prevents cascading restarts during a large deployment.

**End-of-play.** Handlers run after all tasks in the play have finished, not at the point where they were notified. This ensures you restart the service with the final configuration, not an intermediate state.

```
play
├── task: Install nginx          → ok  (no notify fired)
├── task: Deploy nginx.conf      → changed → notifies "Reload nginx"
├── task: Deploy vhost.conf      → changed → notifies "Reload nginx" (deduplicated)
└── HANDLERS
    └── "Reload nginx"           → runs once with the final config in place
```

## Deploy a configuration with a handler

```bash
cat > /root/lab/configure-nginx.yml <<'EOF'
---
- name: Configure nginx on web servers
  hosts: webservers
  become: true

  tasks:
    - name: Deploy nginx virtual host configuration
      copy:
        content: |
          server {
              listen {{ app_port }};
              server_name {{ inventory_hostname }};
              location /health {
                  return 200 'OK\n';
                  add_header Content-Type text/plain;
              }
          }
        dest: /etc/nginx/conf.d/app.conf
        owner: root
        group: root
        mode: '0644'
      notify: Reload nginx configuration

  handlers:
    - name: Reload nginx configuration
      command: nginx -s reload
EOF
```{{exec}}

```bash
cd /root/lab && ansible-playbook configure-nginx.yml
```{{exec}}

The first run: `copy` reports `changed` (the file did not exist). The notification fires. At the end of the play, the handler runs `nginx -s reload`.

Run it again:

```bash
cd /root/lab && ansible-playbook configure-nginx.yml
```{{exec}}

The second run: `copy` reports `ok` — the file content is identical. The notification is **not** sent. The handler does **not** run. Nginx is not reloaded.

This is exactly the behaviour you want in production: zero unnecessary service disruptions.

## force_handlers

By default, if a task fails and the play aborts, any pending handlers that were already notified never run. You can override this:

```yaml
- name: Deploy and configure nginx
  hosts: webservers
  force_handlers: true
  tasks:
    ...
```

With `force_handlers: true`, notified handlers run even if the play fails partway through. This is useful when a handler is a cleanup action that must fire regardless of success or failure.

## Handlers defined in roles

In the next step you will move tasks and handlers into a role. Handlers defined in `roles/<name>/handlers/main.yml` are available to all tasks in that role automatically. You can also `listen` to a topic name instead of a handler name — multiple handlers can subscribe to the same notification topic.
