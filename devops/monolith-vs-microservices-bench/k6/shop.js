// Shop load for the monolith vs microservices bench. Pick the run with SCENARIO.
// Rates (RATE, RAMP_LO, RAMP_HI) are iterations per second; the mix averages 1.05 requests per iteration.
import http from 'k6/http';

const E = __ENV;
const BASE = E.BASE || 'http://app:8080';
const PHASE = Number(E.PHASE || 1); // 0 = warm-up, 1 = measured; keeps checkout users apart
const STEP_S = Number(E.STEP_S || 20);
const ROUTES = ['products_list', 'product_get', 'cart_add', 'cart_get', 'checkout'];
const KNOWN = ['browse-max', 'cart-max', 'checkout-max', 'mix-max', 'mix-fixed', 'mix-ramp', 'mix-sustained', 'warmup'];
const JSON_HDR = { 'Content-Type': 'application/json' };

if (!KNOWN.includes(E.SCENARIO)) throw new Error(`unknown SCENARIO ${E.SCENARIO}`);

const rnd = (n) => 1 + Math.floor(Math.random() * n);

export function browse() {
  if (Math.random() < 0.5) http.get(`${BASE}/products?page=${rnd(500)}`, { tags: { route: 'products_list', name: '/products?page={n}' } });
  else http.get(`${BASE}/products/${rnd(10000)}`, { tags: { route: 'product_get', name: '/products/{id}' } });
}

export function cart() {
  const user = rnd(10000);
  if (Math.random() < 0.5) {
    http.post(`${BASE}/cart/${user}/items`, JSON.stringify({ product_id: rnd(10000), qty: rnd(3) }),
      { headers: JSON_HDR, tags: { route: 'cart_add', name: '/cart/{user}/items' } });
  } else {
    http.get(`${BASE}/cart/${user}`, { tags: { route: 'cart_get', name: '/cart/{user}' } });
  }
}

export function checkout() {
  // Unique per phase, VU, and iteration (__ITER never resets for a VU), far above the 1-10,000 cart users.
  const user = 1e12 * (1 + PHASE) + __VU * 1e6 + __ITER;
  const add = http.post(`${BASE}/cart/${user}/items`, JSON.stringify({ product_id: rnd(10000), qty: 1 }),
    { headers: JSON_HDR, tags: { route: 'cart_add', name: '/cart/{user}/items' } });
  if (add.status >= 200 && add.status < 300) http.post(`${BASE}/checkout/${user}`, null, { tags: { route: 'checkout', name: '/checkout/{user}' } });
}

export function mix() {
  const r = Math.random();
  if (r < 0.80) browse();
  else if (r < 0.95) cart();
  else checkout();
}

// summarize.py repeats this formula (round half up) to know each step's scheduled iterations.
const stepRate = (lo, hi, i) => Math.round(lo + (hi - lo) * i / 9);

function arrival(rate, duration, startTime) {
  const pre = Math.max(1, Math.ceil(rate * 0.5));
  return {
    executor: 'constant-arrival-rate', exec: 'mix', rate, timeUnit: '1s', duration, startTime,
    preAllocatedVUs: pre, maxVUs: 2 * pre, gracefulStop: '2s',
  };
}

function build() {
  const sc = E.SCENARIO;
  if (sc === 'mix-fixed') return { main: arrival(Number(E.RATE), `${E.DUR}s`, '0s') };
  if (sc === 'mix-ramp') {
    const out = {};
    for (let i = 0; i < 10; i++) {
      out[`step${String(i + 1).padStart(2, '0')}`] =
        arrival(stepRate(Number(E.RAMP_LO), Number(E.RAMP_HI), i), `${STEP_S}s`, `${i * STEP_S}s`);
    }
    return out;
  }
  // Closed loop, no think time.
  const flow = { 'browse-max': 'browse', 'cart-max': 'cart', 'checkout-max': 'checkout' }[sc] || 'mix';
  return { main: { executor: 'constant-vus', exec: flow, vus: Number(E.VUS), duration: `${E.DUR}s`, gracefulStop: '2s' } };
}

const SCENARIOS = build();

// No-op thresholds make k6 keep these submetrics in the summary. Tag order: scenario, route, expected_response.
const thresholds = {};
const sub = (metric, tags) => `${metric}{${tags.join(',')}}`;
for (const s of Object.keys(SCENARIOS)) {
  const t = [`scenario:${s}`];
  thresholds[sub('http_reqs', t)] = ['count>=0'];
  thresholds[sub('http_reqs', [...t, 'expected_response:true'])] = ['count>=0'];
  thresholds[sub('http_req_duration', [...t, 'expected_response:true'])] = ['max>=0'];
  thresholds[sub('dropped_iterations', t)] = ['count>=0'];
  thresholds[sub('iterations', t)] = ['count>=0'];
  for (const r of ROUTES) {
    const tr = [...t, `route:${r}`];
    thresholds[sub('http_reqs', tr)] = ['count>=0'];
    thresholds[sub('http_reqs', [...tr, 'expected_response:true'])] = ['count>=0'];
    thresholds[sub('http_req_duration', [...tr, 'expected_response:true'])] = ['max>=0'];
  }
}

export const options = {
  scenarios: SCENARIOS,
  thresholds,
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(50)', 'p(95)', 'p(99)'],
  discardResponseBodies: true,
};

export function handleSummary(data) {
  return { [E.SUMMARY || '/out/summary.json']: JSON.stringify(data) };
}
