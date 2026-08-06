import { RateLimiter } from "./rate-limiter";

export { RateLimiter };

interface Env {
  RATE_LIMITER: DurableObjectNamespace<RateLimiter>;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const apiKey = request.headers.get("x-api-key");
    if (!apiKey) {
      return new Response("Missing x-api-key header", { status: 401 });
    }

    const stub = env.RATE_LIMITER.getByName(apiKey);
    const limiterResponse = await stub.fetch(request);

    if (limiterResponse.status === 429) {
      return limiterResponse;
    }

    return new Response(`request allowed for ${apiKey}`);
  },
};
