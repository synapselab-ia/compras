\set ON_ERROR_STOP on

-- F08 proves the transport primitive itself is transaction-local in real
-- PostgreSQL. These values are artificial and deliberately non-routable.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"https://auth.demo.invalid/neondb/auth","sub":"DEMO-CONTEXT-A"}',
  true
);

DO $$
BEGIN
  IF public.current_auth_issuer() IS DISTINCT FROM 'https://auth.demo.invalid/neondb/auth' THEN
    RAISE EXCEPTION 'issuer unavailable inside local transaction';
  END IF;

  IF public.current_auth_subject() IS DISTINCT FROM 'DEMO-CONTEXT-A' THEN
    RAISE EXCEPTION 'subject unavailable inside local transaction';
  END IF;
END;
$$;
COMMIT;

DO $$
BEGIN
  IF public.current_auth_issuer() IS NOT NULL OR public.current_auth_subject() IS NOT NULL THEN
    RAISE EXCEPTION 'transaction-local claims leaked after commit';
  END IF;
END;
$$;

BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"https://auth.demo.invalid/neondb/auth","sub":"DEMO-CONTEXT-B"}',
  true
);

DO $$
BEGIN
  IF public.current_auth_subject() IS DISTINCT FROM 'DEMO-CONTEXT-B' THEN
    RAISE EXCEPTION 'second transaction did not receive its own subject';
  END IF;
END;
$$;
ROLLBACK;

DO $$
BEGIN
  IF public.current_auth_issuer() IS NOT NULL OR public.current_auth_subject() IS NOT NULL THEN
    RAISE EXCEPTION 'transaction-local claims leaked after rollback';
  END IF;
END;
$$;
