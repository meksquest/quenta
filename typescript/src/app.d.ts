// See https://svelte.dev/docs/kit/types#app.d.ts
// for information about these interfaces
import type { Session } from '$lib/server/db/types.js'
declare global {
  namespace App {
    // interface Error {}
    interface Locals {
      session: Session | undefined
    }
    // interface PageData {}
    // interface PageState {}
    // interface Platform {}
  }
}

export {}
