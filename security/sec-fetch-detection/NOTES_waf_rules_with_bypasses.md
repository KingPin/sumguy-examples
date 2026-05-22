# WAF rules paired with bypass notes (C)

Each rule below is shown with the bypass right next to it. No silver bullets — these are signals, not silver bullets. Use scoring (#3 pipeline), not hard blocks.

## Caddy

### Rule 1: Missing Sec-Fetch-Site on HTML navigation

```caddy
# Catches: curl, Python requests, naive Puppeteer/Selenium pre-stealth
@suspect_no_secfetch {
  method GET
  header Accept *text/html*
  not header Sec-Fetch-Site *
}
handle @suspect_no_secfetch {
  respond "Forbidden" 403
}
```

**Bypass:** Any tool that sets `Sec-Fetch-Site: same-origin` manually. One-liner in any HTTP client.
**Mitigation:** Combine with `Referer` same-origin check on POST endpoints. Score-don't-block on GET.
**False positives:** iOS Safari < 16.4, link unfurlers, RSS readers, search bots. See `NOTES_false_positives.md`.

### Rule 2: UA claims Chrome but Sec-CH-UA absent

```caddy
@chrome_ua_no_uach {
  header_regexp ua User-Agent "Chrome/[0-9]"
  not header Sec-Ch-Ua *
}
respond @chrome_ua_no_uach 403
```

**Bypass:** `curl-impersonate-chrome` sends Sec-CH-UA matching Chrome 116 by default. `puppeteer-extra-plugin-stealth` adds it too.
**Mitigation:** Cross-check `Sec-Ch-Ua` brand string against the major version in UA. Mismatch = score bump.

### Rule 3: Sec-CH-UA-Mobile inconsistent with UA

```caddy
@mobile_mismatch {
  header_regexp ua User-Agent "Mobile|Android|iPhone"
  header Sec-Ch-Ua-Mobile "?0"
}
respond @mobile_mismatch 403
```

**Bypass:** Stealth tools that randomize the mobile flag in sync with the UA defeat this. Recent versions of puppeteer-extra-plugin-stealth do it correctly.
**Mitigation:** Pair with `Sec-Ch-Ua-Platform` check — if UA says iPhone but platform says "Linux", that's a much harder mismatch to fake.

## Nginx

```nginx
map $http_sec_fetch_site $missing_secfetch {
    default 1;
    "" 0;  # explicitly empty handled below
    "none"        0;
    "same-origin" 0;
    "same-site"   0;
    "cross-site"  0;
}

map $http_accept $is_html_request {
    default 0;
    "~*text/html" 1;
}

map "$missing_secfetch:$is_html_request" $block_request {
    default 0;
    "1:1" 1;
}

server {
    if ($block_request) { return 403; }
}
```

**Bypass:** Set `Sec-Fetch-Site: same-origin`. Done.
**Mitigation:** Score, don't block. Feed `$block_request` into a fail2ban filter for rate-limit-then-tarpit.

## Coraza / ModSecurity (scoring, not deny)

```
# Recommended: increment a score, deny only at threshold
SecAction "id:9000,phase:1,pass,nolog,setvar:tx.bot_score=0"

SecRule REQUEST_HEADERS:Accept "@contains text/html" \
  "id:9001,phase:1,chain,pass,setvar:tx.is_html=1"
  SecRule &REQUEST_HEADERS:Sec-Fetch-Site "@eq 0" \
    "setvar:tx.bot_score=+5,msg:'missing Sec-Fetch-Site on HTML nav'"

SecRule REQUEST_HEADERS:User-Agent "@rx Chrome/[0-9]+" \
  "id:9002,phase:1,chain,pass"
  SecRule &REQUEST_HEADERS:Sec-Ch-Ua "@eq 0" \
    "setvar:tx.bot_score=+10,msg:'Chrome UA without Sec-CH-UA'"

SecRule REQUEST_HEADERS:User-Agent "@rx (iPhone|Android)" \
  "id:9003,phase:1,chain,pass"
  SecRule REQUEST_HEADERS:Sec-Ch-Ua-Mobile "@streq ?0" \
    "setvar:tx.bot_score=+10,msg:'mobile UA, desktop UA-CH'"

# Threshold deny
SecRule TX:BOT_SCORE "@ge 15" \
  "id:9099,phase:1,deny,status:403,log,msg:'bot score threshold exceeded'"
```

**Bypass:** Each rule individually is one-line bypassable. The point of the score is that bypassing one still leaves others firing.
**Mitigation:** Tune the threshold by watching your access logs for a week. Start at 20, lower as you confirm no FPs.

## Cloudflare WAF Custom Rules

```
# Expression editor:
(http.request.method eq "GET") and
(http.request.uri.path contains "/") and
not (any(http.request.headers["sec-fetch-site"][*])) and
(any(http.request.headers["accept"][*] contains "text/html"))

# Action: Managed Challenge (NOT block — preserves UX for FPs)
```

**Bypass:** Same as everywhere — spoof the header.
**Mitigation:** Cloudflare's "Bot Score" already factors Sec-Fetch implicitly in Bot Management. If you're paying for Pro+, use their score; if not, this rule is your free version.

## Sec-Fetch as CSRF defense (bonus — #5)

For state-changing endpoints (POST/PUT/DELETE), this single rule replaces a lot of token plumbing:

```caddy
@csrf_attempt {
  method POST PUT DELETE PATCH
  not header Sec-Fetch-Site "same-origin"
}
respond @csrf_attempt 403
```

**Why it works:** A malicious page on `evil.com` that auto-submits a form to `your.site/api/transfer` will trigger `Sec-Fetch-Site: cross-site`. The browser sets this header, and a hostile page cannot override it.

**Limitations / bypass:**
- Doesn't protect against same-origin XSS (attacker is on your domain — that's a different fight).
- Browsers without Sec-Fetch-Site (pre-Safari 16.4) get false positives. Whitelist or fall back to CSRF tokens for those UAs.
- API clients (curl, mobile apps) need explicit allow on Bearer-token-authenticated endpoints.

**Cite:** MDN documents Sec-Fetch-Site as a "fetch metadata request header" with explicit CSRF use case. This isn't novel — it's just under-adopted.
