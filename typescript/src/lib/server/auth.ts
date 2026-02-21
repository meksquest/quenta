import {
  encodeBase32LowerCaseNoPadding,
  encodeHexLowerCase,
} from '@oslojs/encoding'
import { sha256 } from '@oslojs/crypto/sha2'
import type { UserSession } from '$lib/server/db/types.js'
import type { UserId, UserSessionId } from '$lib/ids.js'
import type { KyselyDb } from './db/get-db'
import type { RequestEvent } from '@sveltejs/kit'

type SessionValidationResult = { session: UserSession } | { session: undefined }

function generateSessionToken(): string {
  const bytes = new Uint8Array(20)
  crypto.getRandomValues(bytes)
  const token = encodeBase32LowerCaseNoPadding(bytes)
  return token
}

async function createSession(
  db: KyselyDb,
  token: string,
  userId: UserId,
): Promise<UserSession> {
  const sessionId = encodeHexLowerCase(
    sha256(new TextEncoder().encode(token)),
  ) as UserSessionId
  const session = await db
    .insertInto('userSession')
    .values({
      id: sessionId,
      userId,
      createdAt: Date.now(),
      updatedAt: Date.now(),
      expiresAt: Date.now() + 1000 * 60 * 60 * 24 * 30,
    })
    .returningAll()
    .executeTakeFirstOrThrow()
  return session
}

async function validateSessionToken(
  db: KyselyDb,
  token: string,
): Promise<SessionValidationResult> {
  const sessionId = encodeHexLowerCase(
    sha256(new TextEncoder().encode(token)),
  ) as UserSessionId
  const session = await db
    .selectFrom('userSession')
    .selectAll('userSession')
    .where('userSession.id', '=', sessionId)
    .executeTakeFirst()

  if (!session) {
    return { session: undefined }
  }

  if (Date.now() >= session.expiresAt) {
    await db
      .deleteFrom('userSession')
      .where('userSession.id', '=', session.id)
      .execute()
    return { session: undefined }
  }
  if (Date.now() >= session.expiresAt - 1000 * 60 * 60 * 24 * 15) {
    session.expiresAt = Date.now() + 1000 * 60 * 60 * 24 * 30
    await db
      .updateTable('userSession')
      .set({ expiresAt: session.expiresAt })
      .where('userSession.id', '=', session.id)
      .execute()
  }
  return { session }
}

async function invalidateSession(
  db: KyselyDb,
  sessionId: UserSessionId,
): Promise<void> {
  await db
    .deleteFrom('userSession')
    .where('userSession.id', '=', sessionId)
    .execute()
}

async function invalidateAllSessions(
  db: KyselyDb,
  userId: UserId,
): Promise<void> {
  await db
    .deleteFrom('userSession')
    .where('userSession.userId', '=', userId)
    .execute()
}

function setSessionTokenCookie(
  event: RequestEvent,
  token: string,
  expiresAt: number,
): void {
  event.cookies.set('session', token, {
    httpOnly: true,
    sameSite: 'lax',
    expires: new Date(expiresAt),
    path: '/',
  })
}

function deleteSessionTokenCookie(event: RequestEvent): void {
  event.cookies.set('session', '', {
    httpOnly: true,
    sameSite: 'lax',
    maxAge: 0,
    path: '/',
  })
}

export {
  validateSessionToken,
  invalidateSession,
  invalidateAllSessions,
  generateSessionToken,
  createSession,
  setSessionTokenCookie,
  deleteSessionTokenCookie,
}
