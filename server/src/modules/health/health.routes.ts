import { sql } from 'kysely';
import { z } from 'zod';
import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';

const healthResponse = z.object({
  data: z.object({
    status: z.enum(['ok', 'degraded']),
    database: z.enum(['up', 'down']),
    time: z.string(),
  }),
});

/** Liveness + database reachability. Public; returns no sensitive detail. */
export const healthRoutes: FastifyPluginAsyncZod = async (app) => {
  app.get(
    '/health',
    { schema: { response: { 200: healthResponse, 503: healthResponse } } },
    async (request, reply) => {
      let database: 'up' | 'down' = 'up';
      try {
        await sql`SELECT 1`.execute(app.deps.db);
      } catch (error) {
        request.log.warn({ err: error }, 'health check: database unreachable');
        database = 'down';
      }
      const status = database === 'up' ? 'ok' : 'degraded';
      return reply
        .status(database === 'up' ? 200 : 503)
        .send({ data: { status, database, time: new Date().toISOString() } });
    },
  );
};
