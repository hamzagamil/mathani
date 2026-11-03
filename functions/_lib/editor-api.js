// /api/editor/* (specs/011 contracts/editor-api.md): every request is checked against the
// Access token, then the owner's email or the editor list.
import { verifyAccess } from './access.js';
import { editorStore } from './editor-store.js';

const statusOf = {
  notFound: 404, conflict: 409, invalid: 422, draftChanged: 409, nothingToPublish: 400,
  draftNotEmpty: 409, notEmpty: 409, exists: 409, email: 422,
};

const json = (status, body) =>
  new Response(body === null ? null : JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'private, no-store' },
  });

/** A store result: an `{error}` becomes its status, anything else [ok] (200 or 201). */
const reply = (result, ok = 200) => (result && result.error ? json(statusOf[result.error] ?? 400, result) : json(ok, result));

export async function dispatch(request, env, { fetchCerts, now } = {}) {
  if (!env.DB) return json(503, { error: 'unavailable' });
  const who = await verifyAccess(request, env, { fetchCerts, now: now?.() });
  if (!who) return json(401, { error: 'signIn' });
  const store = editorStore(env.DB, now);
  const owner = String(env.OWNER_EMAIL ?? '').toLowerCase();
  const isOwner = who.email === owner;
  if (!isOwner && !(await store.isEditor(who.email))) {
    return json(403, { error: 'notAnEditor', email: who.email });
  }

  const method = request.method;
  let body = {};
  if (method !== 'GET') {
    const origin = request.headers.get('Origin');
    if (origin && origin !== new URL(request.url).origin) return json(403, { error: 'origin' });
    const type = request.headers.get('Content-Type') ?? '';
    const text = await request.text();
    if (text) {
      if (!type.startsWith('application/json')) return json(415, { error: 'json' });
      try {
        body = JSON.parse(text);
      } catch {
        return json(400, { error: 'json' });
      }
    }
  }

  const path = new URL(request.url).pathname.replace(/^\/api\/editor\/?/, '').split('/').filter(Boolean);
  const [resource, id, action] = path.map(decodeURIComponent);
  const route = `${method} ${resource ?? ''}${id ? ' :id' : ''}${action ? ` ${action}` : ''}`;

  switch (route) {
    case 'GET me':
      return json(200, { email: who.email, isOwner });
    case 'GET groups':
      return json(200, await store.listGroups());
    case 'POST groups':
      return reply(await store.createGroup(body, who.email), 201);
    case 'GET groups :id':
      return reply(await store.getGroup(id));
    case 'PUT groups :id':
      return reply(await store.updateGroup(id, body, who.email));
    case 'DELETE groups :id':
      return reply(await store.setDeleted(id, true, body.revision, who.email));
    case 'POST groups :id undelete':
      return reply(await store.setDeleted(id, false, body.revision, who.email));
    case 'GET publish':
      return json(200, await store.draft());
    case 'POST publish':
      return reply(await store.publish(Array.isArray(body.expect) ? body.expect : [], who.email), 201);
    case 'GET versions':
      return json(200, { versions: await store.listVersions() });
    case 'GET versions :id':
      return reply(await store.getVersion(Number(id)));
    case 'POST versions :id restore':
      return reply(await store.restore(Number(id), body.discardDraft === true, who.email), 201);
    case 'POST import':
      if (!isOwner) return json(403, { error: 'ownerOnly' });
      return reply(await store.importMarkdown(body.markdown, who.email), 201);
    case 'GET editors':
      if (!isOwner) return json(403, { error: 'ownerOnly' });
      return json(200, { editors: await store.listEditors() });
    case 'POST editors':
      if (!isOwner) return json(403, { error: 'ownerOnly' });
      return reply(await store.addEditor(body.email, owner), 201);
    case 'DELETE editors :id': {
      if (!isOwner) return json(403, { error: 'ownerOnly' });
      const result = await store.removeEditor(id);
      return result.error ? reply(result) : json(204, null);
    }
    default:
      return json(404, { error: 'notFound' });
  }
}
