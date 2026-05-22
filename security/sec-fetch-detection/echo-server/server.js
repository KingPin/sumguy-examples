const http = require('http');
const fs = require('fs');

const RESULTS_PATH = process.env.RESULTS_PATH || '/results/raw.jsonl';

const PAGE = `<!DOCTYPE html>
<html><head><title>Sec-Fetch Test</title>
<link rel="stylesheet" href="/style.css?client=__CLIENT__">
<script src="/script.js?client=__CLIENT__"></script>
</head>
<body>
<h1>Sec-Fetch Test Page</h1>
<img src="/image.png?client=__CLIENT__" alt="test">
</body></html>`;

const ONE_PX_PNG = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=',
  'base64'
);

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://${req.headers.host || 'echo'}`);
  const client = url.searchParams.get('client') || 'unknown';

  const record = {
    ts: new Date().toISOString(),
    client,
    method: req.method,
    path: url.pathname,
    headers: req.headers,
  };
  try {
    fs.appendFileSync(RESULTS_PATH, JSON.stringify(record) + '\n');
  } catch (e) {
    console.error('write failed:', e.message);
  }

  if (url.pathname === '/' || url.pathname === '/index.html') {
    res.setHeader('Content-Type', 'text/html');
    res.end(PAGE.replaceAll('__CLIENT__', client));
  } else if (url.pathname === '/style.css') {
    res.setHeader('Content-Type', 'text/css');
    res.end('body{font-family:monospace}');
  } else if (url.pathname === '/script.js') {
    res.setHeader('Content-Type', 'application/javascript');
    res.end('console.log("loaded")');
  } else if (url.pathname === '/image.png') {
    res.setHeader('Content-Type', 'image/png');
    res.end(ONE_PX_PNG);
  } else {
    res.end('ok');
  }
});

const PORT = 8080;
server.listen(PORT, '0.0.0.0', () => console.log(`echo server listening on ${PORT}`));
