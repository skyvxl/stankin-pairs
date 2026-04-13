// ssr=false: content depends on localStorage, SSR would cause hydration flash.
// prerender=true: generates a static HTML shell so the SW can cache and serve it offline.
export const ssr = false;
export const prerender = true;
