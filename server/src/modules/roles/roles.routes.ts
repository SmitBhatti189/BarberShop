import { z } from 'zod';
import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { ForbiddenError } from '../../shared/errors.js';
import { PERMISSIONS } from '../../shared/permissions.js';
import { ok } from '../../shared/response.js';
import { listRoles } from './roles.repository.js';

const roleSchema = z.object({
  id: z.number(),
  name: z.string(),
  description: z.string().nullable(),
  isSystem: z.boolean(),
});

/**
 * GET /roles — the role list, for the employee form's role picker.
 * Open to anyone who manages staff or roles. (Creating and editing roles
 * arrives with the Roles page.)
 */
export const rolesRoutes: FastifyPluginAsyncZod = async (app) => {
  app.get(
    '/roles',
    {
      preHandler: [
        app.authenticate,
        async (request) => {
          const p = request.principal?.permissions;
          if (!p || !(p.has(PERMISSIONS.STAFF_MANAGE) || p.has(PERMISSIONS.ROLES_MANAGE))) throw new ForbiddenError();
        },
      ],
      schema: { response: { 200: z.object({ data: z.array(roleSchema) }) } },
    },
    async () => ok(await listRoles(app.deps.db)),
  );
};
