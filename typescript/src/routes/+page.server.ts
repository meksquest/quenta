import type { PageServerLoad } from './$types.js'

import { getDb } from '$lib/server/db/get-db.js'

const load = (async (event) => {
  const db = getDb()
  console.log('session:', event.locals.session)

  // const result = await db.query(
  //   `SELECT count(id) AS "userCount" FROM public.user`,
  // )
  // const { userCount } = result.rows.at(0)
  const result = await db
    .selectFrom('user')
    .select((eb) => eb.fn.count<number>('id').as('userCount'))
    .executeTakeFirstOrThrow()

  const { userCount } = result

  return {
    userCount,
  }
}) satisfies PageServerLoad

export { load }
