// Base URL of the Martin tile server (no trailing slash).
//
// Production (default): nginx proxies https://yuellen.my.id/martin -> martin:3000.
// Local dev: set VITE_MARTIN_URL=http://localhost:3000 in app/.env.development
//   (loaded by `npm run dev`; production `npm run build` ignores it, so the
//    deployed bundle keeps talking to the production tile server).
export const MARTIN_URL =
  import.meta.env.VITE_MARTIN_URL ?? 'https://yuellen.my.id/martin';
