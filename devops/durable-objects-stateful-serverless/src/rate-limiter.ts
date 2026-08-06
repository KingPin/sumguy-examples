import { DurableObject } from "cloudflare:workers";

const WINDOW_MS = 60_000;
const LIMIT = 30;

export class RateLimiter extends DurableObject {
  async fetch(): Promise<Response> {
    const now = Date.now();
    const windowStart = await this.ctx.storage.get<number>("windowStart");
    let count = (await this.ctx.storage.get<number>("count")) ?? 0;

    // Start a fresh window on the first ever request, and whenever the
    // current one has expired. Persisting windowStart here is the whole
    // trick: skip it and the window never actually begins.
    if (windowStart === undefined || now - windowStart > WINDOW_MS) {
      count = 0;
      await this.ctx.storage.put("windowStart", now);
    }

    count += 1;
    await this.ctx.storage.put("count", count);

    if (count > LIMIT) {
      return new Response("Too Many Requests", {
        status: 429,
        headers: { "Retry-After": "60" },
      });
    }

    return new Response("OK");
  }
}
