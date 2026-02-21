import pg from 'pg'
import { Kysely, PostgresDialect, CamelCasePlugin } from 'kysely'
import type Database from '$lib/__generated__/kanel/Database.js'
import { once } from '$lib/utils/once.js'
import { env as privateEnv } from '$env/dynamic/private'

type KyselyDb = Kysely<Database>

// bigint → number
pg.types.setTypeParser(20, (val) => {
  return Number.parseInt(val, 10)
})

const getDb = once(() => {
  const databaseUrl = privateEnv.DATABASE_URL
  const db = new Kysely<Database>({
    dialect: new PostgresDialect({
      pool: new pg.Pool({
        connectionString: databaseUrl,
      }),
    }),
    plugins: [new CamelCasePlugin()],
  })
  return db
})

export { getDb }
export type { KyselyDb }
