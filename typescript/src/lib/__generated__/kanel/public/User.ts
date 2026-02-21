import type { ColumnType, Selectable, Insertable, Updateable } from 'kysely';

/** Identifier type for public.user */
export type UserId = string & { __brand: 'public.user' };

/** Represents the table public.user */
export default interface UserTable {
  id: ColumnType<UserId, UserId, UserId>;

  name: ColumnType<string, string, string>;

  email: ColumnType<string, string, string>;

  createdAt: ColumnType<number, number, number>;

  updatedAt: ColumnType<number, number, number>;

  googleId: ColumnType<string, string, string>;
}

export type User = Selectable<UserTable>;

export type NewUser = Insertable<UserTable>;

export type UserUpdate = Updateable<UserTable>;