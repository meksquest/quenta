import type { UserId } from './User';
import type { ColumnType, Selectable, Insertable, Updateable } from 'kysely';

/** Identifier type for public.user_session */
export type UserSessionId = string & { __brand: 'public.user_session' };

/** Represents the table public.user_session */
export default interface UserSessionTable {
  id: ColumnType<UserSessionId, UserSessionId, UserSessionId>;

  userId: ColumnType<UserId, UserId, UserId>;

  expiresAt: ColumnType<number, number, number>;

  createdAt: ColumnType<number, number, number>;

  updatedAt: ColumnType<number, number, number>;
}

export type UserSession = Selectable<UserSessionTable>;

export type NewUserSession = Insertable<UserSessionTable>;

export type UserSessionUpdate = Updateable<UserSessionTable>;