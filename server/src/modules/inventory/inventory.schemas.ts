import { z } from 'zod';
import { cursorPageQuery, offsetPageQuery } from '../../shared/pagination.js';
import {
  moneyInput as money,
  optionalText,
  percentInput as percent,
  positiveMoneyInput as positiveMoney,
} from '../../shared/schemas.js';

const quantity = z.number().int('Whole units only').positive('Must be at least 1').max(100_000);

export const purchaseBody = z.object({
  quantity,
  /** Buying price per unit for this delivery. */
  unitCost: money,
  supplierName: optionalText(120),
  invoiceNo: optionalText(60),
  note: optionalText(500),
});
export type PurchaseInput = z.infer<typeof purchaseBody>;

export const ADJUSTMENT_REASONS = [
  'DAMAGED',
  'EXPIRED',
  'USED_IN_SALON',
  'COUNT_CORRECTION',
  'RETURNED_TO_SUPPLIER',
  'OTHER',
] as const;

export const adjustmentBody = z
  .object({
    /** IN adds stock, OUT removes it. */
    direction: z.enum(['IN', 'OUT']),
    quantity,
    reason: z.enum(ADJUSTMENT_REASONS),
    note: optionalText(500),
  })
  .refine((b) => b.reason !== 'OTHER' || Boolean(b.note), { message: 'Say what happened', path: ['note'] });
export type AdjustmentInput = z.infer<typeof adjustmentBody>;

const productFields = {
  name: z.string().trim().min(1, 'Enter a product name').max(120),
  brand: optionalText(80),
  category: optionalText(80),
  mrp: positiveMoney,
  defaultDiscountPct: percent.default('0'),
  lowStockThreshold: z.number().int().min(0).max(100_000).default(0),
};

export const createProductBody = z.object({
  ...productFields,
  /** Optional stock already on the shelf, recorded as the first delivery. */
  openingStock: purchaseBody.optional(),
});
export type CreateProductInput = z.infer<typeof createProductBody>;

export const updateProductBody = z.object({
  version: z.number().int().positive(),
  name: productFields.name.optional(),
  brand: productFields.brand,
  category: productFields.category,
  mrp: positiveMoney.optional(),
  defaultDiscountPct: percent.optional(),
  lowStockThreshold: productFields.lowStockThreshold.unwrap().optional(),
});
export type UpdateProductInput = z.infer<typeof updateProductBody>;

export const listProductsQuery = offsetPageQuery.extend({
  search: z.string().trim().max(100).optional(),
  category: z.string().trim().max(80).optional(),
  status: z.enum(['active', 'inactive', 'all']).default('active'),
  lowStock: z
    .enum(['true', 'false'])
    .transform((v) => v === 'true')
    .optional(),
});
export type ListProductsQuery = z.infer<typeof listProductsQuery>;

export const movementsQuery = cursorPageQuery;
export const productIdParams = z.object({ id: z.coerce.number().int().positive() });

export const productSchema = z.object({
  id: z.number(),
  name: z.string(),
  brand: z.string().nullable(),
  category: z.string().nullable(),
  mrp: z.string(),
  defaultDiscountPct: z.string(),
  /** MRP less the default discount — what billing charges by default. */
  sellingPrice: z.string(),
  /** Buying price of the most recent delivery, if any. */
  lastPurchasePrice: z.string().nullable(),
  stockQuantity: z.number(),
  lowStockThreshold: z.number(),
  isLowStock: z.boolean(),
  isActive: z.boolean(),
  version: z.number(),
});
export type ProductDto = z.infer<typeof productSchema>;

export const movementSchema = z.object({
  id: z.number(),
  type: z.enum(['PURCHASE', 'SALE', 'ADJUSTMENT', 'SALE_REVERSAL']),
  quantityDelta: z.number(),
  unitCost: z.string().nullable(),
  supplierName: z.string().nullable(),
  invoiceNo: z.string().nullable(),
  reason: z.string().nullable(),
  note: z.string().nullable(),
  createdBy: z.string(),
  createdAt: z.string(),
});
export type MovementDto = z.infer<typeof movementSchema>;

export const productResponse = z.object({ data: productSchema });
export const productListResponse = z.object({
  data: z.array(productSchema),
  meta: z.object({ limit: z.number(), offset: z.number(), total: z.number() }),
});
export const stockChangeResponse = z.object({ data: z.object({ product: productSchema, movement: movementSchema }) });
export const movementListResponse = z.object({
  data: z.array(movementSchema),
  meta: z.object({ limit: z.number(), nextCursor: z.string().nullable() }),
});
export const suggestionsResponse = z.object({
  data: z.object({ categories: z.array(z.string()), brands: z.array(z.string()) }),
});
