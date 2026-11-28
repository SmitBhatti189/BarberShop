import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { principalOf, requirePermission } from '../../plugins/auth.js';
import { PERMISSIONS } from '../../shared/permissions.js';
import { ok, okWithMeta } from '../../shared/response.js';
import {
  createStaffBody,
  listStaffQuery,
  loginBody,
  staffIdParams,
  staffListResponse,
  staffResponse,
  updateStaffBody,
} from './staff.schemas.js';
import { StaffService } from './staff.service.js';

/** /staff — employee management. Reading needs staff.view; every change needs staff.manage. */
export const staffRoutes: FastifyPluginAsyncZod = async (app) => {
  const service = new StaffService(app.deps.db);
  const canView = requirePermission(app, PERMISSIONS.STAFF_VIEW);
  const canManage = requirePermission(app, PERMISSIONS.STAFF_MANAGE);

  app.get(
    '/staff',
    { preHandler: canView, schema: { querystring: listStaffQuery, response: { 200: staffListResponse } } },
    async (request) => {
      const { rows, total } = await service.list(request.query);
      return okWithMeta(rows, { limit: request.query.limit, offset: request.query.offset, total });
    },
  );

  app.get(
    '/staff/:id',
    { preHandler: canView, schema: { params: staffIdParams, response: { 200: staffResponse } } },
    async (request) => ok(await service.get(request.params.id)),
  );

  app.post(
    '/staff',
    { preHandler: canManage, schema: { body: createStaffBody, response: { 201: staffResponse } } },
    async (request, reply) => reply.status(201).send(ok(await service.create(request.body))),
  );

  app.patch(
    '/staff/:id',
    { preHandler: canManage, schema: { params: staffIdParams, body: updateStaffBody, response: { 200: staffResponse } } },
    async (request) => ok(await service.update(request.params.id, request.body)),
  );

  app.post(
    '/staff/:id/activate',
    { preHandler: canManage, schema: { params: staffIdParams, response: { 200: staffResponse } } },
    async (request) => ok(await service.setActive(request.params.id, true, principalOf(request))),
  );

  app.post(
    '/staff/:id/deactivate',
    { preHandler: canManage, schema: { params: staffIdParams, response: { 200: staffResponse } } },
    async (request) => ok(await service.setActive(request.params.id, false, principalOf(request))),
  );

  app.put(
    '/staff/:id/login',
    { preHandler: canManage, schema: { params: staffIdParams, body: loginBody, response: { 200: staffResponse } } },
    async (request) => ok(await service.setLogin(request.params.id, request.body, principalOf(request))),
  );

  app.delete(
    '/staff/:id/login',
    { preHandler: canManage, schema: { params: staffIdParams, response: { 200: staffResponse } } },
    async (request) => ok(await service.removeLogin(request.params.id, principalOf(request))),
  );
};
