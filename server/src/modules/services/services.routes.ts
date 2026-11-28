import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { requirePermission } from '../../plugins/auth.js';
import { PERMISSIONS } from '../../shared/permissions.js';
import { ok, okWithMeta } from '../../shared/response.js';
import {
  createServiceBody,
  listServicesQuery,
  serviceCategoriesResponse,
  serviceIdParams,
  serviceListResponse,
  serviceResponse,
  updateServiceBody,
} from './services.schemas.js';
import { ServicesService } from './services.service.js';

/** /services — reading needs services.view; changes need services.manage. */
export const servicesRoutes: FastifyPluginAsyncZod = async (app) => {
  const service = new ServicesService(app.deps.db);
  const canView = requirePermission(app, PERMISSIONS.SERVICES_VIEW);
  const canManage = requirePermission(app, PERMISSIONS.SERVICES_MANAGE);

  app.get(
    '/services',
    { preHandler: canView, schema: { querystring: listServicesQuery, response: { 200: serviceListResponse } } },
    async (request) => {
      const { rows, total } = await service.list(request.query);
      return okWithMeta(rows, { limit: request.query.limit, offset: request.query.offset, total });
    },
  );

  app.get(
    '/services/categories',
    { preHandler: canView, schema: { response: { 200: serviceCategoriesResponse } } },
    async () => ok(await service.categories()),
  );

  app.get(
    '/services/:id',
    { preHandler: canView, schema: { params: serviceIdParams, response: { 200: serviceResponse } } },
    async (request) => ok(await service.get(request.params.id)),
  );

  app.post(
    '/services',
    { preHandler: canManage, schema: { body: createServiceBody, response: { 201: serviceResponse } } },
    async (request, reply) => reply.status(201).send(ok(await service.create(request.body))),
  );

  app.patch(
    '/services/:id',
    { preHandler: canManage, schema: { params: serviceIdParams, body: updateServiceBody, response: { 200: serviceResponse } } },
    async (request) => ok(await service.update(request.params.id, request.body)),
  );

  app.post(
    '/services/:id/activate',
    { preHandler: canManage, schema: { params: serviceIdParams, response: { 200: serviceResponse } } },
    async (request) => ok(await service.setActive(request.params.id, true)),
  );

  app.post(
    '/services/:id/deactivate',
    { preHandler: canManage, schema: { params: serviceIdParams, response: { 200: serviceResponse } } },
    async (request) => ok(await service.setActive(request.params.id, false)),
  );
};
