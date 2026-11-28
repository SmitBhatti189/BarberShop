import type { FastifyPluginAsyncZod } from 'fastify-type-provider-zod';
import { principalOf, requirePermission } from '../../plugins/auth.js';
import { PERMISSIONS } from '../../shared/permissions.js';
import { ok } from '../../shared/response.js';
import {
  paySummaryListResponse,
  salonDefaultBody,
  salonDefaultResponse,
  savePayBody,
  staffIdParams,
  staffPayResponse,
} from './compensation.schemas.js';
import { CompensationService } from './compensation.service.js';

/** /compensation — pay setup. Reading needs compensation.view; changes need compensation.manage. */
export const compensationRoutes: FastifyPluginAsyncZod = async (app) => {
  const service = new CompensationService(app.deps.db);
  const canView = requirePermission(app, PERMISSIONS.COMPENSATION_VIEW);
  const canManage = requirePermission(app, PERMISSIONS.COMPENSATION_MANAGE);

  app.get(
    '/compensation/default',
    { preHandler: canView, schema: { response: { 200: salonDefaultResponse } } },
    async () => ok(await service.salonDefault()),
  );

  app.put(
    '/compensation/default',
    { preHandler: canManage, schema: { body: salonDefaultBody, response: { 200: salonDefaultResponse } } },
    async (request) => ok(await service.setSalonDefault(request.body.defaultCommissionPct)),
  );

  app.get(
    '/compensation/staff',
    { preHandler: canView, schema: { response: { 200: paySummaryListResponse } } },
    async () => ok(await service.summaries()),
  );

  app.get(
    '/compensation/staff/:id',
    { preHandler: canView, schema: { params: staffIdParams, response: { 200: staffPayResponse } } },
    async (request) => ok(await service.staffPay(request.params.id)),
  );

  app.put(
    '/compensation/staff/:id',
    { preHandler: canManage, schema: { params: staffIdParams, body: savePayBody, response: { 200: staffPayResponse } } },
    async (request) => ok(await service.savePay(principalOf(request), request.params.id, request.body)),
  );
};
