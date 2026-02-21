--! Previous: sha1:b23bbe3da008bd2273c83578eacee89d2dfcc1b5
--! Hash: sha1:25786f05e3792383305c169b7c91c8500ac2e194

DROP TABLE IF EXISTS public.user_session;

CREATE TABLE public.user_session (
    id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    expires_at BIGINT NOT NULL,
    created_at BIGINT NOT NULL,
    updated_at BIGINT NOT NULL
);

ALTER TABLE public.user_session
  ADD CONSTRAINT "user_session:primaryKey(id)"
  PRIMARY KEY (id);

ALTER TABLE public.user_session
  ADD CONSTRAINT "user_session:foreignKey(user_id,user)"
  FOREIGN KEY (user_id)
  REFERENCES public.user (id);
