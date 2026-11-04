import { z } from 'zod';

export const MAX_PAGE_LIMIT = 100;
export const DEFAULT_PAGE_LIMIT = 25;

/** Offset pagination for small admin lists (staff, services, products). */
export const offsetPageQuery = z.object({
  limit: z.coerce.number().int().min(1).max(MAX_PAGE_LIMIT).default(DEFAULT_PAGE_LIMIT),
  offset: z.coerce.number().int().min(0).default(0),
});
export type OffsetPageQuery = z.infer<typeof offsetPageQuery>;

export interface OffsetPageMeta {
  limit: number;
  offset: number;
  total: number;
}

/**
 * Keyset (cursor) pagination for ever-growing history (bills, stock movements,
 * ledgers). The cursor is an opaque base64url of the last row's sort key and
 * id, so deep pages stay as fast as the first one.
 */
export const cursorPageQuery = z.object({
  limit: z.coerce.number().int().min(1).max(MAX_PAGE_LIMIT).default(DEFAULT_PAGE_LIMIT),
  cursor: z.string().max(200).optional(),
});
export type CursorPageQuery = z.infer<typeof cursorPageQuery>;

export interface CursorPageMeta {
  limit: number;
  nextCursor: string | null;
}

export interface CursorKey {
  /** ISO timestamp (or other sortable string) of the last row. */
  at: string;
  id: number;
}

export function encodeCursor(key: CursorKey): string {
  return Buffer.from(JSON.stringify(key), 'utf8').toString('base64url');
}

const cursorKeySchema = z.object({ at: z.string(), id: z.number().int().positive() });

export function decodeCursor(cursor: string | undefined): CursorKey | null {
  if (!cursor) return null;
  try {
    return cursorKeySchema.parse(JSON.parse(Buffer.from(cursor, 'base64url').toString('utf8')));
  } catch {
    return null;
  }
}
