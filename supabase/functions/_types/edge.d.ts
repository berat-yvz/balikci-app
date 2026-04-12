// Supabase Edge Functions — Deno ambient type declarations
// VS Code'un kendi TS engine'i için (Deno eklentisi gerektirmez)
// Tüm bildirimler self-contained — dışarıdan npm paketi gerektirmez.

// ── Deno global ──────────────────────────────────────────────────────────────

declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
};

// ── Supabase client minimal tipleri (data: any — downstream hataları önler) ──

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type _AnyData = any;

type SupabaseQueryResult = Promise<{
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  data: _AnyData;
  count?: number | null;
  error: { message: string; code?: string } | null;
}>;

type SupabaseQueryBuilder = {
  select(columns?: string, opts?: { count?: string; head?: boolean }): SupabaseQueryBuilder;
  insert(data: Record<string, unknown> | Record<string, unknown>[]): SupabaseQueryBuilder;
  update(data: Record<string, unknown>): SupabaseQueryBuilder;
  upsert(data: Record<string, unknown>, opts?: { onConflict?: string }): SupabaseQueryBuilder;
  delete(): SupabaseQueryBuilder;
  eq(col: string, val: unknown): SupabaseQueryBuilder;
  neq(col: string, val: unknown): SupabaseQueryBuilder;
  gt(col: string, val: unknown): SupabaseQueryBuilder;
  gte(col: string, val: unknown): SupabaseQueryBuilder;
  lt(col: string, val: unknown): SupabaseQueryBuilder;
  lte(col: string, val: unknown): SupabaseQueryBuilder;
  in(col: string, vals: unknown[]): SupabaseQueryBuilder;
  order(col: string, opts?: { ascending?: boolean }): SupabaseQueryBuilder;
  limit(n: number): SupabaseQueryBuilder;
  range(from: number, to: number): SupabaseQueryBuilder;
  single(): SupabaseQueryResult;
  maybeSingle(): SupabaseQueryResult;
  then<T>(
    onfulfilled: (value: Awaited<SupabaseQueryResult>) => T,
    onrejected?: (reason: unknown) => T,
  ): Promise<T>;
};

type SupabaseStorageFileApi = {
  download(path: string): Promise<{ data: Blob | null; error: { message: string } | null }>;
  upload(path: string, file: unknown, opts?: unknown): Promise<{ data: unknown; error: { message: string } | null }>;
};

type SupabaseBucket = {
  from(bucket: string): SupabaseStorageFileApi;
};

type SupabaseClient = {
  from(table: string): SupabaseQueryBuilder;
  storage: SupabaseBucket;
};

type CreateClient = (url: string, key: string, options?: unknown) => SupabaseClient;

// ── HTTP serve ───────────────────────────────────────────────────────────────

type ServeHandler = (req: Request) => Response | Promise<Response>;
type ServeHandlerNoReq = () => Response | Promise<Response>;

// ── Module declarations ───────────────────────────────────────────────────────

// deno.land/std (iki versiyonu da kapsar)
declare module 'https://deno.land/std@0.177.0/http/server.ts' {
  export function serve(handler: ServeHandler | ServeHandlerNoReq): void;
}
declare module 'https://deno.land/std@0.224.0/http/server.ts' {
  export function serve(handler: ServeHandler | ServeHandlerNoReq): void;
}

// esm.sh Supabase
declare module 'https://esm.sh/@supabase/supabase-js@2' {
  export const createClient: CreateClient;
  export type { SupabaseClient };
}

// npm: prefix Supabase (exif-verify)
declare module 'npm:@supabase/supabase-js@2' {
  export const createClient: CreateClient;
  export type { SupabaseClient };
}

// exifr — EXIF parser (import * as exifr kullanımı)
declare module 'https://esm.sh/exifr@6' {
  export function gps(
    input: unknown,
  ): Promise<{ latitude: number; longitude: number } | null>;
  export function parse(
    input: unknown,
    options?: unknown,
  ): Promise<Record<string, unknown> | null>;
  const _default: {
    gps: typeof gps;
    parse: typeof parse;
    [key: string]: unknown;
  };
  export default _default;
}
