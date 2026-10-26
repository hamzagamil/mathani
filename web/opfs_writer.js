// Writes files into the browser's private file system (OPFS) for browsers whose pages cannot:
// Safari before 26 (every browser on iOS 18 and earlier) has no FileSystemFileHandle
// .createWritable, only createSyncAccessHandle, and only inside a worker (specs/008 research R7).
// lib/platform/file_store_web.dart sends: open {id, dirs, name}, write {id, buffer} (appended at
// the end of the file), close {id}; each is answered {seq, ok, error?} in order.
const handles = new Map();
let queue = Promise.resolve();

self.onmessage = (event) => {
  const m = event.data;
  // One message at a time: a write must not start before its open has finished.
  queue = queue.then(() => handle(m)).then(
    () => self.postMessage({ seq: m.seq, ok: true }),
    (error) => {
      const h = handles.get(m.id);
      if (h) {
        handles.delete(m.id);
        try { h.close(); } catch (_) { /* already closed */ }
      }
      self.postMessage({ seq: m.seq, ok: false, error: (error && error.name) || String(error) });
    },
  );
};

async function handle(m) {
  if (m.type === 'open') {
    let dir = await navigator.storage.getDirectory();
    for (const name of m.dirs) dir = await dir.getDirectoryHandle(name, { create: true });
    const file = await dir.getFileHandle(m.name, { create: true });
    handles.set(m.id, await file.createSyncAccessHandle());
  } else if (m.type === 'write') {
    const h = handles.get(m.id);
    h.write(new Uint8Array(m.buffer), { at: h.getSize() });
  } else if (m.type === 'close') {
    const h = handles.get(m.id);
    handles.delete(m.id);
    if (h) {
      h.flush();
      h.close();
    }
  }
}
