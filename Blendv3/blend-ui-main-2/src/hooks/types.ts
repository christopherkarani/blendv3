import { PoolMetadata, Version } from '@blend-capital/blend-sdk';

export interface PoolMeta extends PoolMetadata {
  id: string;
  version: Version;
}

export const NOT_BLEND_POOL_ERROR_MESSAGE = 'NOT_BLEND_POOL';
