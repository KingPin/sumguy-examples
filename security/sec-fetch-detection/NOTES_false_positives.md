# False-positive exclusion list (D)

Real-world clients that send "weird" or missing Sec-Fetch / UA-CH headers despite being legitimate. Embed this in the article BEFORE the WAF rules so readers don't break their own sites.

## No Sec-Fetch-* headers at all

| Client | What it sends | Why |
|---|---|---|
| iOS Safari < 16.4 | No Sec-Fetch-* | Added in Safari 16.4 (Mar 2023). Older devices still in the wild — older iPads especially. |
| Firefox (any version) re: Sec-CH-UA | No Sec-CH-UA-* | UA-CH is Chromium-only. Firefox supports Sec-Fetch-* but not UA Client Hints. |
| Safari (any version) re: Sec-CH-UA | No Sec-CH-UA-* | Same — Apple has not implemented UA-CH. |
| Tor Browser / Mullvad Browser | Stripped or generic | Privacy-by-design header stripping. |
| Googlebot, Bingbot, DuckDuckBot | No Sec-Fetch-* | They're fetchers, not browsers. **Verify by reverse-DNS, never by UA alone.** |
| facebookexternalhit, Twitterbot, LinkedInBot, Slackbot, Discordbot | No Sec-Fetch-* | Social link unfurlers. Allow if you want preview cards. |
| iMessage / Apple-PubSub | No Sec-Fetch-* | iMessage link previewer. |
| RSS readers (FreshRSS, Miniflux, NetNewsWire, Feedly) | No Sec-Fetch-* | Standard HTTP libraries — your own readers if you self-host. |
| UptimeRobot, Better Uptime, Pingdom, healthchecks.io | No Sec-Fetch-* | Synthetic monitoring. Allowlist by source IP. |
| curl / wget / API clients | No Sec-Fetch-* | Legitimate when hitting `/api/*` paths. |
| Native mobile apps (NSURLSession, OkHttp) | No Sec-Fetch-* | Allow on API endpoints, not on HTML routes. |

## Sends Sec-Fetch-Site but with surprising values

| Scenario | Header value | Why |
|---|---|---|
| User pastes URL into address bar | `Sec-Fetch-Site: none` | Direct navigation, not from a link. **Don't block this** — it's the most common entry path. |
| Bookmarks / "open in new tab" | `Sec-Fetch-Site: none` | Same as above. |
| Cross-origin redirect (OAuth, CDN) | `Sec-Fetch-Site: cross-site` | Legit OAuth callbacks, payment provider returns, etc. |
| User clicks link from Google search | `Sec-Fetch-Site: cross-site` | Half your inbound traffic. |
| Subdomain navigation (blog.example.com → example.com) | `Sec-Fetch-Site: same-site` | Common in multi-subdomain sites. |

## Reduced or spoofed UA-CH

| Client | Behavior |
|---|---|
| Brave | Sends UA-CH but with Brave's anti-fingerprinting reductions — Sec-CH-UA may report Chromium without the Brave brand. |
| Chrome incognito | Same UA-CH as normal Chrome (intentional — to avoid being a fingerprint signal itself). |
| Corporate MITM proxies (Zscaler, Netskope, Forcepoint) | May strip Sec-Fetch-* or Sec-CH-UA-* on re-emission. Common in enterprise networks. |
| Cloudflare-fronted requests | Cloudflare passes Sec-Fetch headers through unmodified by default, but configs vary. |

## Rules of thumb

1. **Never block on a single missing header.** Score it; combine with rate limit, ASN reputation, and behavior.
2. **Always allowlist verified search-engine bots** by reverse-DNS — they're missing all the browser headers and that's correct.
3. **API endpoints are not navigation.** Apply Sec-Fetch checks only to HTML routes (`Accept: text/html` or `Sec-Fetch-Dest: document`).
4. **Test against your own analytics first.** If 20% of your real visitors don't send Sec-CH-UA, the rule doesn't catch bots — it catches your Safari users.
5. **`Sec-Fetch-Site: none` is normal** for direct navigation. Do not block.

## Allowlist sketch (rough)

```text
# Verified by reverse-DNS, not just UA:
googlebot.com, bing.com, search.msn.com, duckduckgo.com,
applebot.apple.com, yandex.com, baidu.com,
crawl.bytedance.com (TikTok crawler)

# Social unfurlers (UA-based — these don't reverse-DNS cleanly):
facebookexternalhit/, Facebot, Twitterbot/, LinkedInBot/,
Slackbot-LinkExpanding/, Discordbot/, TelegramBot,
WhatsApp/, Mastodon/, redditbot

# Monitoring (allowlist by IP, not UA — UAs can be spoofed):
UptimeRobot, Pingdom, Better-Uptime, StatusCake, Hyperping
```
