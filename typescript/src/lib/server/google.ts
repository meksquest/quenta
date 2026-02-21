import { Google } from 'arctic'
import { env as privateEnv } from '$env/dynamic/private'

const google = new Google(
  privateEnv.GOOGLE_CLIENT_ID,
  privateEnv.GOOGLE_CLIENT_SECRET,
  `${privateEnv.ORIGIN}/login/google/callback`,
)

export { google }
