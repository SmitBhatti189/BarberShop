import { z } from 'zod';

export const loginBody = z.object({
  username: z.string().trim().min(1).max(64),
  password: z.string().min(1).max(256),
  deviceLabel: z.string().trim().max(100).optional(),
});
export type LoginBody = z.infer<typeof loginBody>;

export const refreshBody = z.object({
  refreshToken: z.string().min(20).max(200),
});
export type RefreshBody = z.infer<typeof refreshBody>;

export const meSchema = z.object({
  id: z.number(),
  fullName: z.string(),
  branchId: z.number(),
  roleId: z.number(),
  permissions: z.array(z.string()),
});
export type MeDto = z.infer<typeof meSchema>;

export const tokenPairSchema = z.object({
  accessToken: z.string(),
  refreshToken: z.string(),
  /** Access-token lifetime in seconds. */
  expiresIn: z.number(),
  user: meSchema,
});
export type TokenPairDto = z.infer<typeof tokenPairSchema>;

export const loginResponse = z.object({ data: tokenPairSchema });
export const meResponse = z.object({ data: meSchema });
