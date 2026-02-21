import type { default as UserTable } from './User';
import type { default as UserSessionTable } from './UserSession';

export default interface PublicSchema {
  user: UserTable;

  userSession: UserSessionTable;
}