import { z } from 'zod';
import { normalizeMobile } from '../../shared/phone.js';
import { offsetPageQuery } from '../../shared/pagination.js';

const fullName = z.string().trim().min(1, 'Enter a name').max(100);

const mobile = z
  .string()
  .trim()
  .transform((value, ctx) => {
    const normalized = normalizeMobile(value);
    if (!normalized) {
      ctx.addIssue({ code: 'custom', message: 'Enter a 10-digit mobile number' });
      return z.NEVER;
    }
    return normalized;
  });

const email = z.string().trim().toLowerCase().email('Enter a valid email address').max(254);

/** 'YYYY-MM-DD', not in the future. */
const joinedOn = z
  .string()
  .regex(/^\d{4}-\d{2}-\d{2}$/, 'Use YYYY-MM-DD')
  .refine((d) => !Number.isNaN(Date.parse(d)) && d <= new Date().toISOString().slice(0, 10), 'Date cannot be in the future');

export const username = z
  .string()
  .trim()
  .min(3, 'At least 3 characters')
  .max(32)
  .regex(/^[A-Za-z0-9._-]+$/, 'Use letters, numbers, dot, dash or underscore');

export const password = z.string().min(8, 'At least 8 characters').max(128);

export const loginBody = z.object({ username, password });
export type LoginInput = z.infer<typeof loginBody>;

export const createStaffBody = z.object({
  fullName,
  mobile: mobile.nullish(),
  email: email.nullish(),
  roleId: z.number().int().positive(),
  performsServices: z.boolean().default(true),
  joinedOn: joinedOn.nullish(),
  login: loginBody.optional(),
});
export type CreateStaffInput = z.infer<typeof createStaffBody>;

export const updateStaffBody = z.object({
  /** The version the client last saw — protects against two people editing at once. */
  version: z.number().int().positive(),
  fullName: fullName.optional(),
  mobile: mobile.nullish(),
  email: email.nullish(),
  roleId: z.number().int().positive().optional(),
  performsServices: z.boolean().optional(),
  joinedOn: joinedOn.nullish(),
});
export type UpdateStaffInput = z.infer<typeof updateStaffBody>;

export const listStaffQuery = offsetPageQuery.extend({
  search: z.string().trim().max(100).optional(),
  status: z.enum(['active', 'inactive', 'all']).default('active'),
});
export type ListStaffQuery = z.infer<typeof listStaffQuery>;

export const staffIdParams = z.object({ id: z.coerce.number().int().positive() });

export const staffSchema = z.object({
  id: z.number(),
  fullName: z.string(),
  mobile: z.string().nullable(),
  email: z.string().nullable(),
  roleId: z.number(),
  roleName: z.string(),
  isActive: z.boolean(),
  performsServices: z.boolean(),
  joinedOn: z.string().nullable(),
  /** Null = this employee cannot sign in. */
  username: z.string().nullable(),
  version: z.number(),
  createdAt: z.string(),
});
export type StaffDto = z.infer<typeof staffSchema>;

export const staffResponse = z.object({ data: staffSchema });
export const staffListResponse = z.object({
  data: z.array(staffSchema),
  meta: z.object({ limit: z.number(), offset: z.number(), total: z.number() }),
});
