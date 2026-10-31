# excalidraw-self-hosted

Two ways to run Excalidraw on your own box:

- `compose.solo.yaml`: the stock image. Drawings stay in your browser, but every page load fetches fonts from Excalidraw's DigitalOcean CDN and sends a Simple Analytics pageview. Live collaboration, share links, the library browser and the AI tools call excalidraw.com, because those URLs are compiled into the image.
- `compose.yaml`: rebuilds the frontend from source with your own collaboration URL, strips the font CDN and analytics from the built files, runs the official `excalidraw-room` relay, and puts both behind Caddy on one origin. Firebase is switched off. In testing, a page load and a drawing made zero requests outside the host.

Companion to the post: https://sumguy.com/excalidraw-self-hosted/

## Prerequisites

Tested 2026-10-31 with:

- Docker 29.x, Docker Compose 2.17 or newer for `dockerfile_inline` with a git build context (tested on Compose 5.6.1)
- `excalidraw/excalidraw` master at commit `8bcdca4` (built by `compose.yaml`)
- `excalidraw/excalidraw-room:latest` (image built 2023-12-15, Node 12, amd64 only: no ARM image, so no Raspberry Pi)
- `caddy:2`
- About 2 GB of free RAM during the frontend build. At idle the three containers used about 106 MiB.

## Solo mode

```bash
docker compose -f compose.solo.yaml up -d
# open http://localhost:8080
```

## Collaboration mode

`PUBLIC_URL` is the exact origin your browser uses. It is compiled into the JavaScript, so changing it means rebuilding.

```bash
PUBLIC_URL=http://localhost:8080 docker compose up -d --build
# open http://localhost:8080, click "Live collaboration...", "Start session",
# and open the room link in a second browser.
```

The first build runs `yarn install` plus a Vite build and takes several minutes.

For a real deployment:

1. Change `:8080` in `Caddyfile` to your hostname, e.g. `draw.example.com`.
2. Publish `80:80` and `443:443` on the caddy service instead of `8080:8080`.
3. Rebuild with `PUBLIC_URL=https://draw.example.com docker compose up -d --build`.

Collaboration needs HTTPS. Rooms use the browser's Web Crypto API, which only exists in a secure context: `https://` or `http://localhost`. On `http://192.168.x.x` the API is missing and collaboration breaks.

## What you give up with Firebase off

Verified in testing:

- Live drawing and cursors sync through your room server. A late joiner gets the scene from any peer that is still connected.
- The room is not saved anywhere. When the last tab closes, the scene is gone. Save a `.excalidraw` file (Ctrl+S) before you leave.
- Browsers in the session show a warning icon and, once, an error dialog: "Couldn't save to the backend database." This is the disabled Firebase save, and it is expected.
- Pasted images do not sync to other participants (every participant downloads them from Firebase Storage).
- The UI font (Assistant) is not bundled in the image, so the patched build falls back to a system font for menus. Drawing fonts load from the image.
- "Shareable link" export still points at json.excalidraw.com.

If you need persistent rooms, share links and images, look at the community project [alswl/excalidraw-collaboration](https://github.com/alswl/excalidraw-collaboration), which adds an HTTP storage backend. It is not tested here.

## Clean up

```bash
docker compose down
docker image rm excalidraw-selfhosted:local
```
