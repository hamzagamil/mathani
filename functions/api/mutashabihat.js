import { serveContent } from '../_lib/content-api.js';
export const onRequestGet = ({ request, env }) => serveContent(request, env, { cache: caches.default });
