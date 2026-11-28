import { z } from 'zod';

/** Money in as a number or "123.45"; normalised to a 2-decimal-at-most string. */
export const moneyInput = z
  .union([z.number(), z.string()])
  .transform((v) => (typeof v === 'number' ? v.toFixed(2) : v.trim()))
  .refine((v) => /^\d{1,10}(\.\d{1,2})?$/.test(v), 'Enter an amount with at most 2 decimals');

export const positiveMoneyInput = moneyInput.refine((v) => Number(v) > 0, 'Must be more than 0');

/** 0–100 with up to 2 decimals, as a string. */
export const percentInput = z
  .union([z.number(), z.string()])
  .transform((v) => (typeof v === 'number' ? v.toFixed(2) : v.trim()))
  .refine((v) => /^\d{1,3}(\.\d{1,2})?$/.test(v) && Number(v) <= 100, 'Enter a percentage from 0 to 100');

/** Optional free text; blank becomes null (clears the value on edit). */
export const optionalText = (max: number) =>
  z
    .string()
    .trim()
    .max(max)
    .transform((v) => (v === '' ? null : v))
    .nullish();
