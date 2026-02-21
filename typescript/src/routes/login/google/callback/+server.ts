import {
  generateSessionToken,
  createSession,
  setSessionTokenCookie,
} from '$lib/server/auth'
import { google } from '$lib/server/google'
import { decodeIdToken } from 'arctic'
import { randomUUID } from 'node:crypto'

import type { RequestEvent } from '@sveltejs/kit'
import type { OAuth2Tokens } from 'arctic'
import { getDb } from '$lib/server/db/get-db'
import type { UserId } from '$lib/ids'

export async function GET(event: RequestEvent): Promise<Response> {
  const code = event.url.searchParams.get('code')
  const state = event.url.searchParams.get('state')
  const storedState = event.cookies.get('google_oauth_state') ?? null
  const codeVerifier = event.cookies.get('google_code_verifier') ?? null
  if (
    code === null ||
    state === null ||
    storedState === null ||
    codeVerifier === null
  ) {
    return new Response(null, {
      status: 400,
    })
  }
  if (state !== storedState) {
    return new Response(null, {
      status: 400,
    })
  }

  let tokens: OAuth2Tokens
  try {
    tokens = await google.validateAuthorizationCode(code, codeVerifier)
  } catch {
    // Invalid code or client credentials
    return new Response(null, {
      status: 400,
    })
  }
  const claims = decodeIdToken(tokens.idToken()) as {
    sub: string
    name: string
  }
  console.log(JSON.stringify(claims, null, 2))
  const googleUserId = claims.sub
  const username = claims.name

  const db = getDb()
  const existingUser = await db
    .selectFrom('user')
    .select(['user.id'])
    .where('user.googleId', '=', googleUserId)
    .executeTakeFirst()

  if (existingUser) {
    const sessionToken = generateSessionToken()
    const session = await createSession(db, sessionToken, existingUser.id)
    setSessionTokenCookie(event, sessionToken, session.expiresAt)
    return new Response(null, {
      status: 302,
      headers: {
        Location: '/',
      },
    })
  }

  const user = await db
    .insertInto('user')
    .values({
      id: randomUUID() as UserId,
      name: username,
      googleId: googleUserId,
      email: username,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    })
    .returningAll()
    .executeTakeFirstOrThrow()

  const sessionToken = generateSessionToken()
  const session = await createSession(db, sessionToken, user.id)
  setSessionTokenCookie(event, sessionToken, session.expiresAt)
  return new Response(null, {
    status: 302,
    headers: {
      Location: '/',
    },
  })
}
