import { z } from 'zod';
import { percentInput, positiveMoneyInput } from '../../shared/schemas.js';

export const staffIdParams = z.object({ id: z.coerce.number().int().positive() });

export const salonDefaultBody = z.object({ defaultCommissionPct: percentInput });

export const rateInput = z.object({
  itemType: z.enum(['SERVICE', 'PRODUCT']),
  itemId: z.number().int().positive(),
  /** null removes this employee's specific rate (the default rule applies again). */
  ratePct: percentInput.nullable(),
});

export const savePayBody = z
  .object({
    /** null or absent salary = commission-based. */
    monthlySalary: positiveMoneyInput.nullable(),
    /** Only the items listed are changed; others keep their current rate. */
    rates: z.array(rateInput).max(1000).default([]),
  })
  .refine(
    (b) => new Set(b.rates.map((r) => `${r.itemType}:${r.itemId}`)).size === b.rates.length,
    { message: 'Each item may appear only once', path: ['rates'] },
  );
export type SavePayInput = z.infer<typeof savePayBody>;

const rateSource = z.enum(['SPECIFIC', 'DEFAULT', 'NONE']);

export const payItemSchema = z.object({
  itemId: z.number(),
  name: z.string(),
  /** Category for services; brand · category for products. */
  detail: z.string().nullable(),
  /** Service price, or product selling price. */
  price: z.string(),
  /** This employee's own rate, if set. */
  ratePct: z.string().nullable(),
  /** The rate that would actually apply today, and why. */
  effectiveRatePct: z.string().nullable(),
  source: rateSource,
});

export const staffPaySchema = z.object({
  staff: z.object({ id: z.number(), fullName: z.string(), roleName: z.string(), performsServices: z.boolean() }),
  monthlySalary: z.string().nullable(),
  salonDefaultPct: z.string(),
  services: z.array(payItemSchema),
  products: z.array(payItemSchema),
});
export type StaffPayDto = z.infer<typeof staffPaySchema>;

export const paySummarySchema = z.object({
  staffId: z.number(),
  fullName: z.string(),
  roleName: z.string(),
  performsServices: z.boolean(),
  monthlySalary: z.string().nullable(),
  specificRates: z.number(),
});
export type PaySummaryDto = z.infer<typeof paySummarySchema>;

export const salonDefaultResponse = z.object({ data: z.object({ defaultCommissionPct: z.string() }) });
export const staffPayResponse = z.object({ data: staffPaySchema });
export const paySummaryListResponse = z.object({ data: z.array(paySummarySchema) });
