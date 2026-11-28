import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { principalOf, requirePermission } from '../../plugins/auth.js';
import { PERMISSIONS } from '../../shared/permissions.js';
import { ok, okWithMeta } from '../../shared/response.js';
import {
  adjustmentBody,
  createProductBody,
  listProductsQuery,
  movementListResponse,
  movementsQuery,
  productIdParams,
  productListResponse,
  productResponse,
  purchaseBody,
  stockChangeResponse,
  suggestionsResponse,
  updateProductBody,
} from './inventory.schemas.js';
import { InventoryService } from './inventory.service.js';

/** /products — inventory. Reading needs inventory.view; changes need inventory.manage. */
export const inventoryRoutes: FastifyPluginAsyncZod = async (app) => {
  const service = new InventoryService(app.deps.db);
  const canView = requirePermission(app, PERMISSIONS.INVENTORY_VIEW);
  const canManage = requirePermission(app, PERMISSIONS.INVENTORY_MANAGE);

  app.get(
    '/products',
    { preHandler: canView, schema: { querystring: listProductsQuery, response: { 200: productListResponse } } },
    async (request) => {
      const { rows, total } = await service.list(principalOf(request).branchId, request.query);
      return okWithMeta(rows, { limit: request.query.limit, offset: request.query.offset, total });
    },
  );

  app.get(
    '/products/suggestions',
    { preHandler: canView, schema: { response: { 200: suggestionsResponse } } },
    async () => ok(await service.suggestions()),
  );

  app.get(
    '/products/:id',
    { preHandler: canView, schema: { params: productIdParams, response: { 200: productResponse } } },
    async (request) => ok(await service.get(principalOf(request).branchId, request.params.id)),
  );

  app.post(
    '/products',
    { preHandler: canManage, schema: { body: createProductBody, response: { 201: productResponse } } },
    async (request, reply) => reply.status(201).send(ok(await service.create(principalOf(request), request.body))),
  );

  app.patch(
    '/products/:id',
    { preHandler: canManage, schema: { params: productIdParams, body: updateProductBody, response: { 200: productResponse } } },
    async (request) => ok(await service.update(principalOf(request), request.params.id, request.body)),
  );

  app.post(
    '/products/:id/activate',
    { preHandler: canManage, schema: { params: productIdParams, response: { 200: productResponse } } },
    async (request) => ok(await service.setActive(principalOf(request), request.params.id, true)),
  );

  app.post(
    '/products/:id/deactivate',
    { preHandler: canManage, schema: { params: productIdParams, response: { 200: productResponse } } },
    async (request) => ok(await service.setActive(principalOf(request), request.params.id, false)),
  );

  app.post(
    '/products/:id/purchases',
    { preHandler: canManage, schema: { params: productIdParams, body: purchaseBody, response: { 201: stockChangeResponse } } },
    async (request, reply) =>
      reply.status(201).send(ok(await service.receive(principalOf(request), request.params.id, request.body))),
  );

  app.post(
    '/products/:id/adjustments',
    { preHandler: canManage, schema: { params: productIdParams, body: adjustmentBody, response: { 201: stockChangeResponse } } },
    async (request, reply) =>
      reply.status(201).send(ok(await service.adjust(principalOf(request), request.params.id, request.body))),
  );

  app.get(
    '/products/:id/movements',
    { preHandler: canView, schema: { params: productIdParams, querystring: movementsQuery, response: { 200: movementListResponse } } },
    async (request) => {
      const { rows, meta } = await service.movements(
        principalOf(request).branchId,
        request.params.id,
        request.query.limit,
        request.query.cursor,
      );
      return okWithMeta(rows, meta);
    },
  );
};
