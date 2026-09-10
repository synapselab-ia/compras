-- F24 distributed sign-in abuse limiter.
--
-- This migration creates a narrow SECURITY DEFINER primitive in its own
-- namespace. The Auth runtime may execute the primitive but receives no direct
-- table DML, ownership, or policy-control capability.
BEGIN;

DO $f24_auth_role$
DECLARE
  role_row pg_roles%ROWTYPE;
BEGIN
  SELECT *
    INTO role_row
    FROM pg_roles
   WHERE rolname = 'compras_auth_runtime';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'required role compras_auth_runtime does not exist';
  END IF;

  IF role_row.rolsuper
     OR role_row.rolbypassrls
     OR role_row.rolcreatedb
     OR role_row.rolcreaterole
     OR role_row.rolreplication
     OR role_row.rolinherit
     OR NOT role_row.rolcanlogin THEN
    RAISE EXCEPTION 'compras_auth_runtime must remain LOGIN NOINHERIT NOSUPERUSER NOBYPASSRLS NOCREATEDB NOCREATEROLE NOREPLICATION';
  END IF;
END;
$f24_auth_role$;

CREATE SCHEMA auth_guard;

REVOKE ALL PRIVILEGES ON SCHEMA auth_guard FROM PUBLIC;

CREATE TABLE auth_guard.signin_rate_limit_buckets (
  bucket_kind text NOT NULL,
  bucket_digest text NOT NULL,
  window_started_at timestamptz NOT NULL,
  window_ends_at timestamptz NOT NULL,
  attempt_count integer NOT NULL,
  updated_at timestamptz NOT NULL,
  CONSTRAINT signin_rate_limit_buckets_pkey
    PRIMARY KEY (bucket_kind, bucket_digest),
  CONSTRAINT signin_rate_limit_bucket_kind_check
    CHECK (bucket_kind IN ('source', 'identifier', 'pair')),
  CONSTRAINT signin_rate_limit_bucket_digest_check
    CHECK (bucket_digest ~ '^[0-9a-f]{64}$'),
  CONSTRAINT signin_rate_limit_window_check
    CHECK (window_ends_at > window_started_at),
  CONSTRAINT signin_rate_limit_attempt_count_check
    CHECK (attempt_count >= 1)
);

CREATE INDEX signin_rate_limit_buckets_expiry_idx
  ON auth_guard.signin_rate_limit_buckets (window_ends_at);

REVOKE ALL PRIVILEGES
  ON TABLE auth_guard.signin_rate_limit_buckets
  FROM PUBLIC, compras_auth_runtime;

CREATE FUNCTION auth_guard.consume_signin_attempt(
  p_source_digest text,
  p_identifier_digest text,
  p_pair_digest text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, auth_guard
AS $f24_consume$
DECLARE
  v_now timestamptz := clock_timestamp();
  v_source_count integer;
  v_identifier_count integer;
  v_pair_count integer;
BEGIN
  IF p_source_digest IS NULL
     OR p_identifier_digest IS NULL
     OR p_pair_digest IS NULL
     OR p_source_digest !~ '^[0-9a-f]{64}$'
     OR p_identifier_digest !~ '^[0-9a-f]{64}$'
     OR p_pair_digest !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION 'invalid sign-in limiter bucket digest'
      USING ERRCODE = '22023';
  END IF;

  -- Opportunistic cleanup is deliberately bounded. Expired rows never
  -- participate in enforcement; this cleanup only limits physical retention.
  DELETE FROM auth_guard.signin_rate_limit_buckets
   WHERE ctid IN (
     SELECT ctid
       FROM auth_guard.signin_rate_limit_buckets
      WHERE window_ends_at <= v_now
      ORDER BY window_ends_at
      LIMIT 16
      FOR UPDATE SKIP LOCKED
   );

  -- Every caller uses the same lock order (source -> identifier -> pair), which
  -- avoids cross-bucket lock cycles. Fixed policy values are versioned here and
  -- cannot be supplied or widened by the caller.
  INSERT INTO auth_guard.signin_rate_limit_buckets AS bucket (
    bucket_kind,
    bucket_digest,
    window_started_at,
    window_ends_at,
    attempt_count,
    updated_at
  ) VALUES (
    'source',
    p_source_digest,
    v_now,
    v_now + interval '15 minutes',
    1,
    v_now
  )
  ON CONFLICT (bucket_kind, bucket_digest) DO UPDATE
  SET window_started_at = CASE
        WHEN bucket.window_ends_at <= v_now THEN v_now
        ELSE bucket.window_started_at
      END,
      window_ends_at = CASE
        WHEN bucket.window_ends_at <= v_now THEN v_now + interval '15 minutes'
        ELSE bucket.window_ends_at
      END,
      attempt_count = CASE
        WHEN bucket.window_ends_at <= v_now THEN 1
        ELSE bucket.attempt_count + 1
      END,
      updated_at = v_now
  RETURNING attempt_count INTO v_source_count;

  INSERT INTO auth_guard.signin_rate_limit_buckets AS bucket (
    bucket_kind,
    bucket_digest,
    window_started_at,
    window_ends_at,
    attempt_count,
    updated_at
  ) VALUES (
    'identifier',
    p_identifier_digest,
    v_now,
    v_now + interval '15 minutes',
    1,
    v_now
  )
  ON CONFLICT (bucket_kind, bucket_digest) DO UPDATE
  SET window_started_at = CASE
        WHEN bucket.window_ends_at <= v_now THEN v_now
        ELSE bucket.window_started_at
      END,
      window_ends_at = CASE
        WHEN bucket.window_ends_at <= v_now THEN v_now + interval '15 minutes'
        ELSE bucket.window_ends_at
      END,
      attempt_count = CASE
        WHEN bucket.window_ends_at <= v_now THEN 1
        ELSE bucket.attempt_count + 1
      END,
      updated_at = v_now
  RETURNING attempt_count INTO v_identifier_count;

  INSERT INTO auth_guard.signin_rate_limit_buckets AS bucket (
    bucket_kind,
    bucket_digest,
    window_started_at,
    window_ends_at,
    attempt_count,
    updated_at
  ) VALUES (
    'pair',
    p_pair_digest,
    v_now,
    v_now + interval '5 minutes',
    1,
    v_now
  )
  ON CONFLICT (bucket_kind, bucket_digest) DO UPDATE
  SET window_started_at = CASE
        WHEN bucket.window_ends_at <= v_now THEN v_now
        ELSE bucket.window_started_at
      END,
      window_ends_at = CASE
        WHEN bucket.window_ends_at <= v_now THEN v_now + interval '5 minutes'
        ELSE bucket.window_ends_at
      END,
      attempt_count = CASE
        WHEN bucket.window_ends_at <= v_now THEN 1
        ELSE bucket.attempt_count + 1
      END,
      updated_at = v_now
  RETURNING attempt_count INTO v_pair_count;

  RETURN v_source_count <= 120
     AND v_identifier_count <= 20
     AND v_pair_count <= 8;
END;
$f24_consume$;

REVOKE ALL PRIVILEGES
  ON FUNCTION auth_guard.consume_signin_attempt(text, text, text)
  FROM PUBLIC;

GRANT USAGE ON SCHEMA auth_guard TO compras_auth_runtime;
GRANT EXECUTE
  ON FUNCTION auth_guard.consume_signin_attempt(text, text, text)
  TO compras_auth_runtime;

DO $f24_runtime_boundary$
BEGIN
  IF EXISTS (
    SELECT 1
      FROM pg_class c
      JOIN pg_namespace n ON n.oid = c.relnamespace
      JOIN pg_roles r ON r.oid = c.relowner
     WHERE n.nspname = 'auth_guard'
       AND r.rolname = 'compras_auth_runtime'
  ) THEN
    RAISE EXCEPTION 'compras_auth_runtime must not own limiter relations';
  END IF;

  IF has_table_privilege(
    'compras_auth_runtime',
    'auth_guard.signin_rate_limit_buckets',
    'SELECT,INSERT,UPDATE,DELETE'
  ) THEN
    RAISE EXCEPTION 'compras_auth_runtime must not have direct limiter table DML';
  END IF;
END;
$f24_runtime_boundary$;

COMMIT;
