import {
  validateSessionToken,
  setSessionTokenCookie,
  deleteSessionTokenCookie,
} from '$lib/server/auth.js'
import { getDb } from '$lib/server/db/get-db'

import type { Handle } from '@sveltejs/kit'

export const handle: Handle = async ({ event, resolve }) => {
  const token = event.cookies.get('session')
  if (!token) {
    event.locals.session = undefined
    return resolve(event)
  }

  const db = getDb()

  const { session } = await validateSessionToken(db, token)
  if (session) {
    setSessionTokenCookie(event, token, session.expiresAt)
  } else {
    deleteSessionTokenCookie(event)
  }

  event.locals.session = session
  return resolve(event)
}
