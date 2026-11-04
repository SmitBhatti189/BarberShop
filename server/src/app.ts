import Fastify, { type FastifyInstance, type FastifyServerOptions } from 'fastify';
import cors from '@fastify/cors';
import { serializerCompiler, validatorCompiler, type ZodTypeProvider } from 'fastify-type-provider-zod';
import { corsOrigins, type Env } from './config/env.js';
import type { Db } from './db/database.js';
import { authPlugin } from './plugins/auth.js';
import { errorHandlerPlugin } from './plugins/error-handler.js';
import { authRoutes } from './modules/auth/auth.routes.js';
import { healthRoutes } from './modules/health/health.routes.js';

/** Everything route modules may depend on. Injected, so tests can swap parts. */
export interface AppDeps {
  env: Env;
  db: Db;
}

declare module 'fastify' {
  interface FastifyInstance {
    deps: AppDeps;
  }
}

export const API_PREFIX = '/api/v1';

/**
 * Builds the HTTP app without listening, so tests can use `app.inject()`.
 * Module routes are registered under /api/v1 as they are implemented.
 */
export async function buildApp(deps: AppDeps, logger: FastifyServerOptions['logger'] = true): Promise<FastifyInstance> {
  const app = Fastify({
    logger,
    // Unique id per request, echoed in logs for tracing a single operation.
    genReqId: () => crypto.randomUUID(),
    bodyLimit: 1024 * 1024,
  }).withTypeProvider<ZodTypeProvider>();

  app.setValidatorCompiler(validatorCompiler);
  app.setSerializerCompiler(serializerCompiler);
  app.decorate('deps', deps);

  await app.register(errorHandlerPlugin);
  await app.register(cors, {
    origin: corsOrigins(deps.env),
    methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
    allowedHeaders: ['Authorization', 'Content-Type', 'Idempotency-Key'],
  });
  await app.register(authPlugin, {
    secret: deps.env.JWT_ACCESS_SECRET,
    accessTokenTtlSeconds: deps.env.JWT_ACCESS_TTL_SECONDS,
  });

  await app.register(
    async (api) => {
      await api.register(healthRoutes);
      await api.register(authRoutes);
    },
    { prefix: API_PREFIX },
  );

  return app;
}
