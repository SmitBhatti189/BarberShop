import { z } from 'zod';
import { offsetPageQuery } from '../../shared/pagination.js';
import { moneyInput, optionalText } from '../../shared/schemas.js';

const fields = {
  name: z.string().trim().min(1, 'Enter a service name').max(120),
  category: optionalText(80),
  description: optionalText(500),
  price: moneyInput,
  durationMinutes: z.number().int('Whole minutes only').min(1, 'At least 1 minute').max(600, 'At most 10 hours'),
};

export const createServiceBody = z.object(fields);
export type CreateServiceInput = z.infer<typeof createServiceBody>;

export const updateServiceBody = z.object({
  version: z.number().int().positive(),
  name: fields.name.optional(),
  category: fields.category,
  description: fields.description,
  price: fields.price.optional(),
  durationMinutes: fields.durationMinutes.optional(),
});
export type UpdateServiceInput = z.infer<typeof updateServiceBody>;

export const listServicesQuery = offsetPageQuery.extend({
  search: z.string().trim().max(100).optional(),
  category: z.string().trim().max(80).optional(),
  status: z.enum(['active', 'inactive', 'all']).default('active'),
});
export type ListServicesQuery = z.infer<typeof listServicesQuery>;

export const serviceIdParams = z.object({ id: z.coerce.number().int().positive() });

export const serviceSchema = z.object({
  id: z.number(),
  name: z.string(),
  category: z.string().nullable(),
  description: z.string().nullable(),
  price: z.string(),
  durationMinutes: z.number(),
  isActive: z.boolean(),
  version: z.number(),
});
export type ServiceDto = z.infer<typeof serviceSchema>;

export const serviceResponse = z.object({ data: serviceSchema });
export const serviceListResponse = z.object({
  data: z.array(serviceSchema),
  meta: z.object({ limit: z.number(), offset: z.number(), total: z.number() }),
});
export const serviceCategoriesResponse = z.object({ data: z.array(z.string()) });
