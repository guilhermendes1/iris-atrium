# IRIS Atrium

A browser-based administration console for InterSystems IRIS. IRIS Atrium is a
single, demo-ready Angular single-page app that inspects and operates an IRIS
instance through the platform's native management APIs (security, tasks,
processes, web applications, OS and logs) — no SQL, no direct global access
from the browser, and no dependency on the vendor's own Management Portal UI.

The console is organized into six sections:

1. **Web Apps & REST API Explorer** — list web applications; explore and test the
   OpenAPI spec of any REST-enabled app installed on the instance.
2. **Permissions** — list IRIS users, roles and resources; edit user role
   assignments and enable/disable users.
3. **Security & Secrets** — dashboard of SSL configurations, X.509 credentials,
   wallets and OAuth clients (read-only).
4. **Tasks** — view scheduled tasks and history; run, suspend and resume tasks.
5. **Operating System** — CPU/memory/disk dashboard, namespaces and the IRIS
   process list with terminate support.
6. **Logs** — unified viewer over console, messages, audit and task history with
   filters and CSV export.

## Stack

- **Backend**: InterSystems IRIS Community Edition (`mp` ObjectScript package,
  `%CSP.REST` dispatch class `mp.disp`).
- **Frontend**: Angular 17 single-page app built with Node (`web/`).
- **Tooling**: Docker + Compose, ZPM module `iris-atrium`, GitHub Actions CI,
  `%UnitTest.Manager` suites under `tests/UnitTest`.

## How the application works

### Overall architecture

```text
Browser (Angular SPA)
   │  HTTPS/HTTP, Basic auth on every request
   ▼
/webapps, /permissions, /security, /tasks, /system, /logs
   │
   ▼
CSP web application "/csp/iris-atrium"           (static SPA shell)
CSP REST web application "/api/mp"               (mp.disp %CSP.REST router)
   │
   ▼
mp.disp  →  mp.impl.{webapps, permissions, security, tasks, system, logs}
   │
   ▼
IRIS native management APIs (what actually powers the console):
   Security.Users / Security.Roles / Security.Resources / Security.Applications
   Security.SSLConfigs / Security.X509Credentials / Security.Wallets / SSL
   %SYS.Task + TaskHistory / %SYS.ProcessQuery / Config.Namespaces
   %SYSTEM.OBJ (file system) / ^$SYSTEM files (messages.log, console.log)
   %SYS.Configuration, HSM, etc.
```

The browser never talks to IRIS globals or SQL. Every panel is served by
`/api/mp`, a thin `%CSP.REST` facade (dispatch class `mp.disp`) that delegates to
one implementation class per domain. Each implementation maps the request onto
the corresponding *InterSystems IRIS management API* — the same classes the
native Management Portal uses — and returns a small JSON envelope to the SPA.

### Request flow (concrete example)

1. The Angular service builds a URL under `/api/mp`, e.g. `GET /api/mp/tasks`.
2. `mp.disp` (the `%CSP.REST` router) matches the path, checks that the caller
   holds the required privilege (e.g. `%Admin_Task`), and invokes
   `mp.impl.tasks.List()`.
3. The implementation queries the IRIS management APIs
   (`##class(%SYS.Task).%ExistsId()`, `##class(%SYS.Task).%OpenId()`,
   `##class(%SYS.Task).RunNow()`, `%SYS.TaskHistory`) and shapes the rows.
4. The result is serialized to JSON (`mp.util.json`) and returned with the
   proper status code.
5. The Angular component renders the table / chart / form from the JSON.

### Authentication & session

- Login (`POST /api/mp/login`) validates the credentials against IRIS and the
  *entire* session is driven by each request carrying
  `Authorization: Basic <base64(user:password)>`.
- The SPA stores that header in `localStorage` (keys `mp.credentials`,
  `mp.username`) and an Angular HTTP interceptor re-attaches it to every call.
- No cookie or JWT is used; authorization is re-evaluated by IRIS on every
  request, so revoking a user or dropping a role takes effect immediately.
- Privilege enforcement happens server-side: each `/api/mp` route carries a
  minimum privilege (`%Admin_Manage`, `%Admin_Secure`, `%Admin_Task`,
  `%Admin_Operate`) and returns `403` for callers who lack it.

### Request body encoding

The 2026.1 community CSP gateway strips double quotes from POST/PUT bodies,
corrupting `application/json` payloads. The API therefore transports JSON as
base64 in a `body64` query parameter (`/api/mp/...?body64=<encoded>`) with an
empty HTTP body. The SPA handles this transparently in `api.service.ts`.

### The six sections, powered by which IRIS management API

| Section | SPA routes | `/api/mp` endpoints | IRIS management API behind it |
|---|---|---|---|
| Web Apps | `/webapps`, `/webapps/explorer` | `/webapps`, `/webapps/installed`, `/webapps/spec` | `Security.Applications`, `/api/mgmnt` |
| Permissions | `/permissions` | `/users`, `/roles`, `/resources`, `/users/:name/roles`, `/users/:name/enabled` | `Security.Users`, `Security.Roles`, `Security.Resources` |
| Security & Secrets | `/security` | `/security/credentials[/:type[/:alias]]` | `Security.SSLConfigs`, `Security.X509Credentials`, `Security.Wallets`, OAuth2 config |
| Tasks | `/tasks` | `/tasks`, `/tasks/history`, `/tasks/:guid/run`, `/tasks/:guid/suspend`, `/tasks/:guid/resume` | `%SYS.Task`, `%SYS.TaskHistory` |
| Operating System | `/system` | `/system/metrics`, `/system/disks`, `/system/namespaces`, `/system/processes`, `/system/processes/:pid/terminate` | `%SYS.ProcessQuery`, `Config.Namespaces`, OS calls via `$System.Util` |
| Logs | `/logs` | `/logs/sources`, `/logs`, `/logs/export` | IRIS log files (`messages.log`, `console.log`, audit) parsed in ObjectScript |

## Requirements

Only Docker is required (Docker Desktop or Docker Engine + Compose). All other
tooling runs inside the container. Port `52773` must be free.

## IRIS Community Edition license & high-core hosts

The InterSystems IRIS Community Edition license limits the runtime to a maximum number
of visible CPU cores (up to 20 for current community releases). On hosts that expose
more cores than the license allows, IRIS aborts at startup with *"Invalid Community
Edition license, may have exceeded core limit"*. Because this image boots IRIS during
`docker compose build` too, the build can hit the same failure.

This stack ships a self-contained fix — no license key, no Docker VM changes:

- The base image is pinned to the vendor-maintained `intersystemsdc/iris-community`
  `latest` stream (valid, non-expired community license; overridable via the
  `IRIS_IMAGE` build argument, e.g. `docker compose build --build-arg IRIS_IMAGE=...`).
- `scripts/iris-entrypoint.sh` heads off `/iris-main` at build **and** runtime, wrapping
  the process in a `taskset` CPU-affinity mask via `scripts/limit-cores.sh` so IRIS never
  observes more than `MP_MAX_CORES` cores (default `19`, i.e. under the 20-core ceiling).
- On hosts already at or below `MP_MAX_CORES` cores the wrapper is a no-op, so low-core
  machines behave exactly as before.

To override the visible-core bound (must stay below the license ceiling for the fix to
hold):

```bash
MP_MAX_CORES=4 docker compose up -d
```

## Quickstart

```bash
docker compose up -d --build
```

- IRIS becomes healthy: `docker compose ps` shows the `iris` service `healthy`.
- IRIS Atrium: <http://localhost:52773/csp/iris-atrium/index.html>
- Demo login: `SuperUser` / `SYS`

> **Base image notes**: the `latest` community stream runs a full CSP subsystem, so
> class-dispatch web apps (including `/api/mp`) work over HTTP exactly as on a
> licensed instance. The `intersystemsdc/iris-community:latest-em-zpm` stream boots
> with a limited CSP subsystem: static pages serve normally, but **no web
> application that dispatches to a class (`DispatchClass`) accepts requests** — every
> such endpoint answers `401`/`403`/`404` regardless of credentials. When that image
> is selected via `IRIS_IMAGE`, the portal's HTTP API cannot be demonstrated over
> HTTP; the `%UnitTest.Manager` suites still run in the terminal inside the image.

## Demo walkthrough (six sections)

1. **Web Apps & REST API Explorer** — open **Web Apps**; verify the list shows
   `/csp/...` applications with name, path, namespace and authentication. Open
   **API Explorer**, pick an installed REST app (e.g. `/api/mgmnt`), confirm the
   OpenAPI spec renders and fire a sample GET returning HTTP 200.
2. **Permissions** — open **Permissions**, pick a user, edit a role assignment and
   confirm it persists.
3. **Security & Secrets** — open **Security**; verify the SSL/x509/wallet/OAuth
   dashboard renders (entries may be few on a fresh instance).
4. **Tasks** — open **Tasks**; click **Run Now** on a harmless task (e.g.
   `Purge Audit`) and confirm a new `Finished` history entry.
5. **Operating System** — open **OS Management**; confirm the CPU/memory/disk
   dashboard loads within 5 seconds; the process list loads from
   `%SYS.ProcessQuery`. Terminating a process requires `%Admin_Operate` and a
   confirmation dialog.
6. **Logs** — open **Logs**; apply a `source=Console` filter, then **Export** the
   filtered entries as a CSV download.

## REST API

All endpoints live under `/api/mp` and require HTTP Basic
credentials (`Authorization: Basic <base64(user:password)>`). The SPA obtains those
credentials from its login screen and sends them on every request.

| Method | Path | Purpose | Resource gate |
|---|---|---|---|
| POST | `/api/mp/login` | Validate credentials | none |
| GET  | `/api/mp/session` | Current session | none (login) |
| GET  | `/api/mp/webapps` | List web applications | `%Admin_Manage` |
| GET  | `/api/mp/webapps/installed` | REST apps via `/api/mgmnt` | `%Admin_Manage` |
| GET  | `/api/mp/webapps/spec?ns=&app=` | OpenAPI spec proxy | `%Admin_Manage` |
| POST | `/api/mp/webapps` | Create web app (`name` in JSON) | `%Admin_Manage` |
| PUT  | `/api/mp/webapps` | Modify web app (`name` in JSON) | `%Admin_Manage` |
| DELETE | `/api/mp/webapps?name=` | Delete web app | `%Admin_Manage` |
| GET  | `/api/mp/users`, `/api/mp/roles`, `/api/mp/resources` | List security objects | `%Admin_Secure` |
| PUT  | `/api/mp/users/:username/roles` | Replace role assignments | `%Admin_Secure` |
| POST | `/api/mp/users`, PUT `/api/mp/users/:username`, PUT `/api/mp/users/:username/enabled` | User CRUD | `%Admin_Secure` |
| GET  | `/api/mp/security/credentials[/:type[/:alias]]` | Credentials dashboard | `%Admin_Secure` |
| GET  | `/api/mp/tasks`, GET `/api/mp/tasks/history` | Schedule + history | `%Admin_Tasks` |
| POST | `/api/mp/tasks/:guid/run`, PUT `/api/mp/tasks/:guid/suspend`, PUT `/api/mp/tasks/:guid/resume` | Task control | `%Admin_Tasks` |
| GET  | `/api/mp/system/metrics`, `/disks`, `/namespaces`, `/processes` | OS dashboard | `%Admin_Operate` |
| POST | `/api/mp/system/processes/:pid/terminate` | Terminate process | `%Admin_Operate` |
| GET  | `/api/mp/logs`, `/api/mp/logs/sources`, `/api/mp/logs/export` | Unified log viewer | `%Admin_Operate` |

Response envelope: `200 {...}` on success; errors are `{ "error": "...", "message":
"..." }` with HTTP 4xx/5xx.

> **Note on request bodies.** The 2026.1 community CSP gateway strips double quotes
> from POST/PUT bodies, corrupting `application/json` payloads. The API therefore
> transports JSON as base64 in a `body64` query parameter (`/api/mp/login?body64=<...>`)
> with an empty body; the SPA adds this automatically in `api.service.ts`.

## Automated tests

ObjectScript unit tests run inside the container (mirrors CI):

```bash
docker compose exec -T iris iris session IRIS -U USER 'do ##class(%UnitTest.Manager).RunTest("/opt/mgmt/tests")'
```

Angular unit tests run locally in `web/`:

```bash
cd web && npm ci && npm test -- --watch=false --browsers=ChromeHeadless
```

## Local Angular development

```bash
cd web
npm ci
npm run build    # outputs to web/dist (not required for the Docker path)
```

The container bakes the SPA at build time; a local build is only needed to iterate.

## Project layout

```text
src/mp/                  ObjectScript backend (package mp)
  disp.cls               %CSP.REST router
  Installer.cls          USER-namespace + web-app bootstrap
  impl/                  Endpoint implementations (six areas + session)
  util/                  json + security helpers
web/                     Angular SPA
tests/UnitTest/          %UnitTest.Manager suites (per portal section)
docker-compose.yml       IRIS service, port 52773
Dockerfile               node build stage + IRIS community stage
scripts/                 Core-cap wrapper (limit-cores.sh) + entrypoint override
iris.script              Container bootstrap
module.xml               ZPM module metadata
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| Port 52773 in use | Change the `ports` mapping in `docker-compose.yml` |
| `401 Unauthorized` on login | Username/password must reference an existing IRIS user |
| Web Apps empty | Log in with an account holding `%Admin_Manage` (e.g. `SuperUser`) |
| Logs empty | Open **Logs**, check *sources* health; audit requires audit read rights |
| OS dashboard blank | Returns `[]`/zeros for metrics the container cannot read (kept graceful) |
| Build or startup aborts: *"Invalid Community Edition license, may have exceeded core limit"* | Keep `MP_MAX_CORES` set (default `19`); rebuild with `docker compose build` so the build-time boot runs under the core cap. See "IRIS Community Edition license & high-core hosts". |

## License

MIT — see [LICENSE](LICENSE).