// mthani-khatma-ops (specs/014 research R14): runs on its two schedules only.
import { EmailMessage } from 'cloudflare:email';

import { mimeMessage, notifyReports, removeExpired } from './jobs.js';

/** Sends a report to the owner: by email, or to REPORT_WEBHOOK when email is not set up. */
function sender(env) {
  if (env.EMAIL) {
    return (subject, text) => env.EMAIL.send(new EmailMessage(env.REPORT_FROM, env.OWNER_EMAIL,
      mimeMessage({ from: env.REPORT_FROM, to: env.OWNER_EMAIL, subject, text })));
  }
  if (env.REPORT_WEBHOOK) {
    return async (subject, text) => {
      const r = await fetch(env.REPORT_WEBHOOK, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ subject, text }),
      });
      if (!r.ok) throw new Error(`webhook ${r.status}`);
    };
  }
  return async () => {
    throw new Error('no way to reach the owner');
  };
}

export default {
  async scheduled(event, env) {
    if (event.cron === '0 3 * * *') {
      await removeExpired(env.KHATMA_DB);
    } else {
      await notifyReports(env.KHATMA_DB, sender(env), { page: env.REPORTS_PAGE });
    }
  },
};
