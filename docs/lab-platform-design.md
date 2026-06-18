# Building a Killercoda-like Lab Platform — Design Doc

> Status: design / decision reference
> Audience: devoriales.com maintainers
> Goal: run our own interactive-lab platform so users can **take** (and eventually **create**) hands-on Kubernetes labs, as simply as possible.

---

## 1. Context

We author interactive Kubernetes labs (Gateway API, Goldilocks) in this repo using
Killercoda's content format:

- markdown steps (`stepN/text.md`)
- exit-code checks (`stepN/verify.sh`)
- silent setup (`background.sh`)
- scenario/course manifests (`structure.json`, `index.json`)
- a single-node Kubernetes VM backend (`kubernetes-kubeadm-1node`)

This doc describes what it would take to run that experience on our own platform.

**Constraints / decisions made up front:**

| Decision | Choice | Implication |
|---|---|---|
| Audience | Semi-trusted students (authenticated, from devoriales.com) — not the open internet | Isolation must be solid but not adversarial-grade |
| Per-session runtime | A plain Linux sandbox **with a small Kubernetes (k3s/kind) running inside it** | Matches Killercoda's single-node model; this is the right instinct |
| Hosting | Start simple, scale later | One VM first, not autoscaling K8s |

**The key realization:** the hard part is **not** the website. It is giving every user a
disposable, isolated environment that can itself run Kubernetes. Everything else
(lesson rendering, terminal, "Check" button, login) is standard web plumbing. The rest of
this doc is organized around that one hard problem.

---

## 2. The one hard problem — the session sandbox

Each session needs an isolated environment where the student has root, runs `kubectl`, and
a real k3s cluster boots inside. A normal container can't safely run its own
kubelet/systemd, so we need one of these:

| Option | Isolation | Density / cost | Build effort | Verdict |
|---|---|---|---|---|
| **VM per session** — a small cloud VM running k3s | Strong (full VM) | Low density, higher cost | **Lowest** | Best for an MVP / low concurrency |
| **Sysbox container per session** — [Sysbox](https://github.com/nestybox/sysbox) runtime runs systemd + k3s in an unprivileged-ish container | Good — fine for semi-trusted | **High density, cheap** | Medium | Best long-term sweet spot |
| **Firecracker microVM** — what Killercoda/Katacoda use | Strong | High density | High (ops-heavy) | Overkill unless we go public-scale |

**Recommendation:** begin with **one VM per session** for the fastest possible MVP, then
migrate to **Sysbox containers** for density and cost once the rest of the platform works.
Avoid Firecracker until/unless we open to the public.

> Rule of thumb: each k3s session wants ~1–2 GB RAM. Size hosts accordingly.

---

## 3. Two routes

### Route A (genuinely simplest): adopt an existing OSS platform — Educates

This category already has a strong open-source option:
[**Educates**](https://github.com/educates/educates-training-platform), built by Graham
Dumpleton (author of the original Katacoda Kubernetes content). It is purpose-built for
exactly our use case:

- Markdown-based workshop content — very close to our `text.md` step model
- Embedded browser terminal + lesson pane + optional dashboard/editor
- Each session = an isolated namespace, optionally a [vcluster](https://www.vcluster.com/),
  on a host Kubernetes cluster → **"k8s inside the session" is solved for us**
- Built-in setup / verify hooks → maps to `background.sh` / `verify.sh`

**Effort:** install Educates on one Kubernetes cluster, port scenarios to its workshop
format. Days, not months.

**Use Route A if** the goal is *running labs*. This is the recommended starting point — the
only real cost is porting the content format, and it eliminates the entire sandbox problem.

### Route B: build a minimal platform ourselves

**Use Route B if** we want to own the product: custom UI, our own auth, and "users create
labs" as a first-class feature. Full architecture below.

---

## 4. Route B architecture

```
Browser (student)
  ├─ Lesson pane: renders markdown steps (text.md)
  ├─ Terminal pane: xterm.js  ──WebSocket──┐
  └─ "Check" button ───────────────────────┼─► Control plane (backend)
                                            │
Control plane (Go or Node)                  │
  • auth (students)                         │
  • parse structure.json / index.json       │
  • create / destroy session sandbox        │
  • run background.sh on boot               │
  • run verify.sh on "Check" → pass/fail    │
  • idle TTL + teardown                     │
  • proxy terminal WebSocket ───────────────┘
        │
        ▼
Session sandbox (VM or Sysbox container) — one per session
  • ttyd            ← ready-made web terminal over WebSocket
  • k3s installed   ← the "small kubernetes"
  • /root/manifests ← populated from repo assets
```

### 4.1 Simplest stack

| Concern | Pick | Why |
|---|---|---|
| Frontend | React / Next.js (or a static page) + [`xterm.js`](https://xtermjs.org/) + `react-markdown` | Terminal + rendered lesson steps. Nothing exotic. |
| Web terminal in sandbox | [`ttyd`](https://github.com/tsl0922/ttyd) | Browser terminal over WebSocket out of the box. **Do not hand-roll PTY plumbing.** |
| Control plane | One small **Go** or **Node** service | Creates/destroys sandboxes (Docker API for Sysbox, or a VM provider API), proxies WebSockets, execs `verify.sh` / `background.sh`. |
| Sandbox image | Ubuntu + `k3s` + `ttyd` + `helm` / `kubectl` / `mkcert` | Mirror what `background.sh` expects. **Pre-pull k3s images into the image** so boot is fast. |
| Reverse proxy / TLS | [Caddy](https://caddyserver.com/) or Traefik | Automatic HTTPS + subdomain-per-session routing (`s-<id>.labs.example.com`) to expose a student's NodePort/Ingress, like Killercoda's "Traffic / Ports". |
| Persistence | **Postgres** (users, courses, progress) | Content itself stays in Git. |
| Content source | **This Git repo, pulled by the control plane** | Same model as Killercoda linking one GitHub repo. |
| Session lifecycle | TTL + idle timeout in the control plane | Destroy sandbox on expiry. **Essential for cost control.** |

### 4.2 Reuse the existing content model as-is

Our repo is already a clean content spec. The control plane only needs to:

1. Read root `structure.json` → courses → per-course `structure.json` → scenarios.
2. Read each `index.json` for steps + asset mappings.
3. Copy `manifests/**` to `/root/manifests` in the sandbox (the `assets` key).
4. Render each `stepN/text.md`; run `stepN/verify.sh` on "Check"; run `background.sh` on boot.

**No content rewrite needed for Route B.** (Route A / Educates would require a one-time
format port.)

### 4.3 Hosting

Start on **one beefy VM**: control plane + Docker-with-Sysbox (or a VM-spawning provider) +
Caddy, all on that box. Dead simple, cheap, fine for tens of concurrent sessions.

Scale later by adding worker nodes and scheduling sandboxes across them (a small Kubernetes
cluster, or Nomad) — but **only when we actually outgrow one VM**. Don't start with
autoscaling K8s; it's premature complexity.

---

## 5. Route B build sequence (MVP)

1. **Sandbox image** — Ubuntu + k3s + ttyd + tooling. Verify by hand: run it, confirm
   `kubectl get nodes` works inside and ttyd serves a terminal.
2. **Control plane: boot + terminal** — endpoint that creates a sandbox, runs
   `background.sh`, returns the ttyd WebSocket URL. Proxy it through Caddy.
3. **Frontend** — lesson pane (render `text.md`) + xterm.js wired to the proxied terminal.
4. **Verify loop** — "Check" button → control plane execs `verify.sh` → show pass/fail.
5. **Auth + progress** — student login, Postgres, per-step completion.
6. **Lifecycle** — TTL / idle teardown, per-user concurrency limit.
7. *(Later)* **"Users create labs"** — a web editor that writes the same
   `index.json` / `structure.json` / `text.md` / `verify.sh` structure (PR to a Git repo, or
   DB-backed).

---

## 6. How to validate each route

**Route A (Educates):** install on a test cluster (local kind or a small cloud K8s), port
one scenario (e.g. `gateway-api/scenario-1-baseline`), launch a session, confirm the
terminal works and a verify step passes.
→ *Decision gate:* does the format port feel acceptable?

**Route B (MVP):** end-to-end test —
log in → open a scenario → terminal connects → `background.sh` ran (cluster/app present) →
complete a step → "Check" runs `verify.sh` and reports correctly → session tears down after
TTL. Validate isolation by confirming one session can't see another's k3s.

---

## 7. Bottom line

- **The sandbox is the whole game** — don't under- or over-engineer it. Use a VM per
  session for the first MVP, move to Sysbox + k3s for density. The "Linux shell with a small
  k8s inside" instinct is exactly right.
- **Simplest of all:** evaluate **Educates (Route A)** before building. It may already be
  ~90% of what we want, and removes the sandbox problem entirely.
- **If building (Route B):** `xterm.js` + `ttyd` + a thin Go/Node control plane +
  VM-or-Sysbox/k3s + Caddy + Postgres, on one VM, reusing this repo as the content source.

---

## References

- [Educates training platform](https://github.com/educates/educates-training-platform)
- [Sysbox container runtime](https://github.com/nestybox/sysbox)
- [ttyd — share terminal over the web](https://github.com/tsl0922/ttyd)
- [xterm.js](https://xtermjs.org/)
- [k3s](https://k3s.io/) · [kind](https://kind.sigs.k8s.io/)
- [Caddy](https://caddyserver.com/) · [vcluster](https://www.vcluster.com/)
