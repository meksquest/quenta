--! Previous: -
--! Hash: sha1:b23bbe3da008bd2273c83578eacee89d2dfcc1b5

-- Create user table

drop table if exists public.user;

create table public.user (
  id text not null,
  name text not null,
  email text not null,
  created_at bigint not null,
  updated_at bigint not null
);

alter table public.user
  add constraint "user:primaryKey(id)"
  primary key (id);
