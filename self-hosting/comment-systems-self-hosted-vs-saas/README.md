# Comment Systems: Self-Hosted Examples

Working Compose files for self-hosted blog comment systems. Companion to the article:
**[Blog Comments: Self-Host or SaaS?](https://sumguy.com/posts/comment-systems-self-hosted-vs-saas/)**

---

## What's in this folder

| File | What it runs |
|------|-------------|
| `docker-compose.yml` | Remark42 — recommended all-rounder |
| `docker-compose.isso.yml` | Isso — minimal anonymous commenting |
| `isso.cfg` | Isso config file (required alongside the Isso Compose file) |

---

## Prerequisites

- Docker 27.x or newer
- Docker Compose v2.x (`docker compose` not `docker-compose`)
- A domain with DNS pointing to your server
- A reverse proxy (Caddy, Nginx, Traefik) to handle HTTPS — both services run HTTP on their respective ports

---

## Remark42

### Setup

1. Create OAuth apps:
   - **GitHub:** Settings → Developer settings → OAuth Apps → New. Callback: `https://comments.yourdomain.com/auth/github/callback`
   - **Google (optional):** Google Cloud Console → APIs & Services → Credentials → Create OAuth client. Redirect: `https://comments.yourdomain.com/auth/google/callback`

2. Edit `docker-compose.yml` — fill in every placeholder value:
   - `REMARK_URL` — the public HTTPS URL of your Remark42 instance
   - `SECRET` — generate with `openssl rand -hex 32`
   - `SITE` — any identifier string for your blog
   - OAuth client IDs and secrets
   - `ADMIN_SHARED_ID` — your GitHub username in `github_yourusername` format
   - SMTP settings (optional but recommended for comment notifications)

3. Start it:

```bash
docker compose up -d
```

4. Verify it's running:

```bash
docker compose logs -f remark42
```

### Embedding on your blog

Add to your post template (Astro, Hugo, Jekyll, etc.):

```html
<div id="remark42"></div>
<script>
  var remark_config = {
    host: "https://comments.yourdomain.com",
    site_id: "myblog",
    components: ["embed"],
  };
  (function(c) {
    for (var i = 0; i < c.length; i++) {
      var d = document, s = d.createElement('script');
      s.src = remark_config.host + '/web/' + c[i] + '.js';
      s.defer = true;
      (d.head || d.body).appendChild(s);
    }
  })(remark_config.components || ['embed']);
</script>
```

Full embed docs: https://remark42.com/docs/getting-started/installation/

---

## Isso

### Setup

1. Edit `isso.cfg`:
   - Set `host` to your blog's public URL
   - Fill in SMTP settings for moderation email notifications

2. Start it alongside its config:

```bash
docker compose -f docker-compose.isso.yml up -d
```

3. Verify:

```bash
docker compose -f docker-compose.isso.yml logs -f isso
```

### Embedding on your blog

```html
<script data-isso="https://isso.yourdomain.com/"
        src="https://isso.yourdomain.com/js/embed.min.js"></script>
<section id="isso-thread">
  <noscript>JavaScript required to view comments.</noscript>
</section>
```

---

## Reverse proxy notes

Both services run plain HTTP. Put them behind HTTPS using your existing reverse proxy.

**Caddy example (Remark42):**

```text
comments.yourdomain.com {
    reverse_proxy remark42:8080
}
```

**Caddy example (Isso):**

```text
isso.yourdomain.com {
    reverse_proxy isso:8080
}
```

---

## Tested with

- Docker 27.5.1
- Docker Compose v2.32.4
- Remark42 v1.14.x
- Isso 0.13.x

---

## Back to the article

Full writeup, decision guide, and SaaS alternatives:
https://sumguy.com/posts/comment-systems-self-hosted-vs-saas/
