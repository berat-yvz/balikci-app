// Supabase Edge Functions — Deno ambient type declarations
// VS Code'un kendi TS engine'i için (Deno eklentisi gerektirmez)

declare const Deno: {
  env: {
    get(key: string): string | undefined;
  };
};

// deno.land/std HTTP server
declare module 'https://deno.land/std@0.177.0/http/server.ts' {
  export function serve(
    handler: (req: Request) => Response | Promise<Response>,
  ): void;
}

// esm.sh Supabase client — @supabase/supabase-js'in tüm tiplerini yeniden export eder
declare module 'https://esm.sh/@supabase/supabase-js@2' {
  export { createClient, SupabaseClient } from '@supabase/supabase-js';
  export type {
    PostgrestError,
    PostgrestResponse,
    User,
    Session,
    AuthError,
  } from '@supabase/supabase-js';
}
