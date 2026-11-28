import type { Db } from '../../db/database.js';
import { ConflictError, NotFoundError } from '../../shared/errors.js';
import * as repo from './services.repository.js';
import type { CreateServiceInput, ListServicesQuery, ServiceDto, UpdateServiceInput } from './services.schemas.js';

/**
 * Salon services and their current prices. Bills copy a service's name and
 * price when they are created, so editing a price here never changes history.
 */
export class ServicesService {
  constructor(private readonly db: Db) {}

  list(query: ListServicesQuery) {
    return repo.listServices(this.db, query);
  }

  categories() {
    return repo.categories(this.db);
  }

  async get(id: number): Promise<ServiceDto> {
    const service = await repo.findService(this.db, id);
    if (!service) throw new NotFoundError('Service');
    return service;
  }

  async create(input: CreateServiceInput): Promise<ServiceDto> {
    const id = await withDuplicateName(() =>
      repo.insertService(this.db, {
        name: input.name,
        category: input.category ?? null,
        description: input.description ?? null,
        price: input.price,
        durationMinutes: input.durationMinutes,
      }),
    );
    return this.get(id);
  }

  async update(id: number, input: UpdateServiceInput): Promise<ServiceDto> {
    const saved = await withDuplicateName(() =>
      repo.updateServiceIfVersion(this.db, id, input.version, {
        ...(input.name !== undefined && { name: input.name }),
        ...(input.category !== undefined && { category: input.category }),
        ...(input.description !== undefined && { description: input.description }),
        ...(input.price !== undefined && { price: input.price }),
        ...(input.durationMinutes !== undefined && { duration_minutes: input.durationMinutes }),
      }),
    );
    if (!saved) {
      await this.get(id); // 404 if missing
      throw new ConflictError('STALE', 'Someone else changed this service. Reload and try again.');
    }
    return this.get(id);
  }

  async setActive(id: number, active: boolean): Promise<ServiceDto> {
    await this.get(id);
    await withDuplicateName(() => repo.setServiceActive(this.db, id, active));
    return this.get(id);
  }
}

async function withDuplicateName<T>(work: () => Promise<T>): Promise<T> {
  try {
    return await work();
  } catch (error) {
    const e = error as { code?: string; constraint?: string };
    if (e.code === '23505' && e.constraint === 'services_name_active_uq') {
      throw new ConflictError('DUPLICATE', 'An active service with this name already exists', [
        { field: 'name', message: 'An active service with this name already exists' },
      ]);
    }
    throw error;
  }
}
