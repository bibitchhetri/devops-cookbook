const express = require('express');
const client = require('prom-client');
const pino = require('pino');

const app = express();
const PORT = 3000;

const logger = pino({
  level: 'info',
  formatters: {
    level: (label) => {
      return { level: label };
    },
  },
});

const register = new client.Registry();

client.collectDefaultMetrics({ register });

const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'endpoint', 'status_code'],
  registers: [register],
});

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'endpoint', 'status_code'],
  buckets: [0.01, 0.05, 0.1, 0.5, 1, 2, 5],
  registers: [register],
});

const httpRequestsInProgress = new client.Gauge({
  name: 'http_requests_in_progress',
  help: 'Number of HTTP requests in progress',
  labelNames: ['method', 'endpoint'],
  registers: [register],
});

app.use(express.json());

app.use((req, res, next) => {
  const start = Date.now();
  const endpoint = req.route?.path || req.path;

  httpRequestsInProgress.inc({ method: req.method, endpoint });

  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const statusCode = res.statusCode.toString();

    httpRequestsTotal.inc({ method: req.method, endpoint, status_code: statusCode });
    httpRequestDuration.observe({ method: req.method, endpoint, status_code: statusCode });
    httpRequestsInProgress.dec({ method: req.method, endpoint });

    logger.info({
      method: req.method,
      url: req.url,
      status: statusCode,
      duration_ms: Date.now() - start,
      endpoint,
    });
  });

  next();
});

app.get('/metrics', async (req, res) => {
  try {
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (err) {
    logger.error({ err: err.message }, 'Error generating metrics');
    res.status(500).end(err.message);
  }
});

app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'UP',
    message: 'Server is healthy'
  });
});

app.get('/users', (req, res) => {
  const users = [
    { id: 1, name: 'Alice' },
    { id: 2, name: 'Bob' }
  ];

  res.status(200).json(users);
});

module.exports = app;

if (require.main === module) {
  app.listen(PORT, () => {
    logger.info({ port: PORT }, 'Server started');
  });
}
