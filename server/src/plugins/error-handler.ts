import fp from 'fastify-plugin';
import type { FastifyError } from 'fastify';
import { hasZodFastifySchemaValidationErrors, isResponseSerializationError } from 'fastify-type-provider-zod';
import { AppError } from '../shared/errors.js';

interface ErrorBody {
  error: { code: string; message: string; details?: unknown };
}

// PostgreSQL constraint violations that indicate a client-side conflict rather
// than a server bug. Constraint names are never exposed to the client.
const PG_CONFLICTS: Record<string, { status: number; code: string; message: string }> = {
  '23505': { status: 409, code: 'DUPLICATE', message: 'A record with the same unique value already exists' },
  '23P01': { status: 409, code: 'CONFLICT', message: 'The request overlaps with an existing record' },
  '23503': { status: 409, code: 'REFERENCE_CONFLICT', message: 'The record is referenced by or references missing data' },
  '23514': { status: 422, code: 'CONSTRAINT_VIOLATION', message: 'The values break a data rule' },
};

/**
 * Central error mapping → `{ error: { code, message, details } }`.
 * Unknown errors are logged with the request id and returned as a generic 500.
 */
export const errorHandlerPlugin = fp(async (app) => {
  app.setErrorHandler((error: FastifyError, request, reply) => {
    if (error instanceof AppError) {
      return reply.status(error.statusCode).send(body(error.code, error.message, error.details));
    }

    if (hasZodFastifySchemaValidationErrors(error)) {
      const details = error.validation.map((v) => ({
        field: [error.validationContext, v.instancePath.replace(/^\//, '').replaceAll('/', '.')].filter(Boolean).join('.'),
        message: v.message,
      }));
      return reply.status(400).send(body('VALIDATION_ERROR', 'Request validation failed', details));
    }

    const pgCode = (error as { code?: string }).code;
    const pgConflict = pgCode ? PG_CONFLICTS[pgCode] : undefined;
    if (pgConflict && 'routine' in error) {
      request.log.info({ err: error }, 'database constraint rejected request');
      return reply.status(pgConflict.status).send(body(pgConflict.code, pgConflict.message));
    }

    if (isResponseSerializationError(error)) {
      request.log.error({ err: error }, 'response did not match its schema');
      return reply.status(500).send(body('INTERNAL_ERROR', 'An unexpected error occurred'));
    }

    // Fastify's own 4xx errors (malformed JSON, payload too large, …).
    if (error.statusCode && error.statusCode >= 400 && error.statusCode < 500) {
      return reply.status(error.statusCode).send(body(error.code ?? 'BAD_REQUEST', error.message));
    }

    request.log.error({ err: error }, 'unhandled error');
    return reply.status(500).send(body('INTERNAL_ERROR', 'An unexpected error occurred'));
  });

  app.setNotFoundHandler((request, reply) => {
    reply.status(404).send(body('NOT_FOUND', `Route ${request.method} ${request.url} not found`));
  });
});

function body(code: string, message: string, details?: unknown): ErrorBody {
  return details === undefined ? { error: { code, message } } : { error: { code, message, details } };
}
