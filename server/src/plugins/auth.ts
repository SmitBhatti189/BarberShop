import fp from 'fastify-plugin';
import fastifyJwt from '@fastify/jwt';
import type { FastifyReply, FastifyRequest, preHandlerAsyncHookHandler } from 'fastify';
import { ForbiddenError, UnauthorizedError } from '../shared/errors.js';
import type { PermissionKey } from '../shared/permissions.js';
import { findActivePrincipal, type Principal } from '../modules/auth/principal.repository.js';

/** Claims carried by the short-lived access token. */
export interface AccessTokenClaims {
  sub: string; // staff id
  sid: number; // auth_sessions id
}

declare module '@fastify/jwt' {
  interface FastifyJWT {
    payload: AccessTokenClaims;
    user: AccessTokenClaims;
  }
}

declare module 'fastify' {
  interface FastifyRequest {
    principal: Principal | null;
  }
  interface FastifyInstance {
    /** preHandler: requires a valid access token for an active staff session. */
    authenticate: preHandlerAsyncHookHandler;
  }
}

export interface AuthPluginOptions {
  secret: string;
  accessTokenTtlSeconds: number;
}

export const authPlugin = fp<AuthPluginOptions>(async (app, opts) => {
  await app.register(fastifyJwt, {
    secret: opts.secret,
    sign: { expiresIn: opts.accessTokenTtlSeconds, algorithm: 'HS256' },
    verify: { algorithms: ['HS256'] },
  });

  app.decorateRequest('principal', null);

  app.decorate('authenticate', async function authenticate(request: FastifyRequest, _reply: FastifyReply) {
    let claims: AccessTokenClaims;
    try {
      claims = await request.jwtVerify<AccessTokenClaims>();
    } catch {
      throw new UnauthorizedError('Invalid or expired access token');
    }
    const staffId = Number(claims.sub);
    if (!Number.isSafeInteger(staffId) || !Number.isSafeInteger(claims.sid)) {
      throw new UnauthorizedError('Invalid access token');
    }
    const principal = await findActivePrincipal(app.deps.db, staffId, claims.sid);
    if (!principal) throw new UnauthorizedError('Session is no longer valid');
    request.principal = principal;
  });
});

/**
 * Route guard: authenticates, then requires ALL of the given permissions.
 *   app.get('/customers', { preHandler: requirePermission(app, PERMISSIONS.CUSTOMERS_VIEW) }, …)
 */
export function requirePermission(
  app: { authenticate: preHandlerAsyncHookHandler },
  ...required: PermissionKey[]
): preHandlerAsyncHookHandler[] {
  return [
    app.authenticate,
    async (request) => {
      const granted = request.principal?.permissions;
      if (!granted || !required.every((key) => granted.has(key))) throw new ForbiddenError();
    },
  ];
}

/** Narrowing helper for handlers that run after `authenticate`. */
export function principalOf(request: FastifyRequest): Principal {
  if (!request.principal) throw new UnauthorizedError();
  return request.principal;
}
