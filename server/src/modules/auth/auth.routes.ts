import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { principalOf } from '../../plugins/auth.js';
import { ok } from '../../shared/response.js';
import { loginBody, loginResponse, meResponse, refreshBody } from './auth.schemas.js';
import { AuthService, toMeDto } from './auth.service.js';

/**
 * /auth — public login/refresh, authenticated logout/me.
 * Thin controller layer: validation is declared in the schema, all logic
 * lives in AuthService.
 */
export const authRoutes: FastifyPluginAsyncZod = async (app) => {
  const service = new AuthService({
    db: app.deps.db,
    signAccessToken: (claims) => app.jwt.sign(claims),
    accessTokenTtlSeconds: app.deps.env.JWT_ACCESS_TTL_SECONDS,
    refreshTokenTtlDays: app.deps.env.REFRESH_TOKEN_TTL_DAYS,
  });

  app.post('/auth/login', { schema: { body: loginBody, response: { 200: loginResponse } } }, async (request) =>
    ok(await service.login(request.body, request.ip)),
  );

  app.post('/auth/refresh', { schema: { body: refreshBody, response: { 200: loginResponse } } }, async (request) =>
    ok(await service.refresh(request.body.refreshToken)),
  );

  app.post('/auth/logout', { preHandler: app.authenticate }, async (request, reply) => {
    await service.logout(principalOf(request));
    return reply.status(204).send();
  });

  app.get('/auth/me', { preHandler: app.authenticate, schema: { response: { 200: meResponse } } }, async (request) =>
    ok(toMeDto(principalOf(request))),
  );
};
