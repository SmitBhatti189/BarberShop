/** Consistent success envelope: `{ data, meta? }`. */
export interface ApiResponse<T, M = undefined> {
  data: T;
  meta?: M;
}

export function ok<T>(data: T): ApiResponse<T> {
  return { data };
}

export function okWithMeta<T, M>(data: T, meta: M): { data: T; meta: M } {
  return { data, meta };
}
