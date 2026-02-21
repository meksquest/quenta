--! Previous: sha1:25786f05e3792383305c169b7c91c8500ac2e194
--! Hash: sha1:a7a66e84e525556bfb19249ae1a0919b8d5ffd4f

DELETE FROM public.user;
ALTER TABLE public.user DROP COLUMN IF EXISTS "google_id";
ALTER TABLE public.user ADD COLUMN "google_id" TEXT NOT NULL;
