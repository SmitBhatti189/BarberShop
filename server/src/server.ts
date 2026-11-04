import { buildApp } from './app.js';
import { loadEnv } from './config/env.js';
import { createDb } from './db/database.js';

const env = loadEnv();
const db = createDb({ connectionString: env.DATABASE_URL });

const app = await buildApp(
  { env, db },
  {
    level: env.LOG_LEVEL,
    // Human-readable logs while developing; structured JSON otherwise.
    ...(env.NODE_ENV === 'development' ? { transport: { target: 'pino-pretty' } } : {}),
    redact: ['req.headers.authorization', 'req.body.password', 'req.body.refreshToken'],
  },
);

// Graceful shutdown: stop accepting requests, finish in-flight ones, close the pool.
let shuttingDown = false;
for (const signal of ['SIGINT', 'SIGTERM'] as const) {
  process.on(signal, async () => {
    if (shuttingDown) return;
    shuttingDown = true;
    app.log.info({ signal }, 'shutting down');
    await app.close();
    await db.destroy();
    process.exit(0);
  });
}

try {
  await app.listen({ host: env.HOST, port: env.PORT });
} catch (error) {
  app.log.fatal({ err: error }, 'failed to start');
  await db.destroy();
  process.exit(1);
}
