\set ON_ERROR_STOP on

-- Additional F35 edge cases over the synthetic fixtures created by
-- contracting_item_create.sql. This file runs in the same disposable database.

-- Force a terminal allocator value before entering the unprivileged runtime.
UPDATE public.contracting_item_ordinal_counters
SET last_ordinal = 2147483647
WHERE contracting_id = '35040000-0000-4000-8000-000000000002'::uuid;

SET SESSION AUTHORIZATION compras_domain_runtime_f35_ci;

BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F35-A"}', true
);

-- Zero is valid, spaces-only description remains exact and NULL optional text
-- remains NULL. Target one previously ended at ordinal 2, so this must be 3.
SELECT test_support_f35.assert_text(
  $$SELECT public.create_contracting_item(
      '35040000-0000-4000-8000-000000000001'::uuid,
      '   ', 0::numeric, NULL, NULL,
      '35060000-0000-4000-8000-000000000103'::uuid,
      '35070000-0000-4000-8000-000000000103'::uuid
    )$$,
  'created', 'zero quantity and spaces-only description are valid'
);
SELECT test_support_f35.assert_text(
  $$SELECT ordinal::text FROM public.contracting_items
    WHERE id = '35060000-0000-4000-8000-000000000103'::uuid$$,
  '3', 'zero quantity create advances ordinal'
);
SELECT test_support_f35.assert_text(
  $$SELECT description FROM public.contracting_items
    WHERE id = '35060000-0000-4000-8000-000000000103'::uuid$$,
  '   ', 'spaces-only description preserved exactly'
);
SELECT test_support_f35.assert_text(
  $$SELECT quantity::text FROM public.contracting_items
    WHERE id = '35060000-0000-4000-8000-000000000103'::uuid$$,
  '0', 'zero quantity persisted'
);
SELECT test_support_f35.assert_count(
  $$SELECT count(*) FROM public.contracting_items
    WHERE id = '35060000-0000-4000-8000-000000000103'::uuid
      AND unit IS NULL
      AND catalog_code IS NULL$$,
  1, 'NULL unit/catalog remain NULL'
);
COMMIT;

-- A non-convertible textual quantity fails before the primitive body. The
-- nested block gives the failure its own subtransaction so residue can be
-- checked without aborting this disposable proof session.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F35-A"}', true
);
DO $invalid_quantity$
BEGIN
  BEGIN
    PERFORM public.create_contracting_item(
      '35040000-0000-4000-8000-000000000001'::uuid,
      'DEMO invalid quantity',
      'not-a-postgres-numeric'::numeric,
      NULL,
      NULL,
      '35060000-0000-4000-8000-000000000104'::uuid,
      '35070000-0000-4000-8000-000000000104'::uuid
    );
    RAISE EXCEPTION 'expected invalid textual numeric cast failure';
  EXCEPTION
    WHEN invalid_text_representation THEN
      NULL;
  END;
END;
$invalid_quantity$;
SELECT test_support_f35.assert_count(
  $$SELECT count(*) FROM public.contracting_items
    WHERE id = '35060000-0000-4000-8000-000000000104'::uuid$$,
  0, 'invalid numeric creates no item'
);
SELECT test_support_f35.assert_count(
  $$SELECT count(*) FROM public.contracting_events
    WHERE id = '35070000-0000-4000-8000-000000000104'::uuid$$,
  0, 'invalid numeric creates no event'
);
COMMIT;

-- Integer ordinal overflow must fail instead of wrapping or inventing a new
-- ordinal policy. Target two has an allocator deliberately set to INT_MAX.
BEGIN;
SELECT set_config(
  'request.jwt.claims',
  '{"iss":"urn:compras:better-auth:self-hosted:v1","sub":"DEMO-F35-A"}', true
);
DO $ordinal_overflow$
BEGIN
  BEGIN
    PERFORM public.create_contracting_item(
      '35040000-0000-4000-8000-000000000002'::uuid,
      'DEMO ordinal overflow',
      NULL,
      NULL,
      NULL,
      '35060000-0000-4000-8000-000000000105'::uuid,
      '35070000-0000-4000-8000-000000000105'::uuid
    );
    RAISE EXCEPTION 'expected integer ordinal overflow';
  EXCEPTION
    WHEN numeric_value_out_of_range THEN
      NULL;
  END;
END;
$ordinal_overflow$;
SELECT test_support_f35.assert_count(
  $$SELECT count(*) FROM public.contracting_items
    WHERE id = '35060000-0000-4000-8000-000000000105'::uuid$$,
  0, 'ordinal overflow creates no item'
);
SELECT test_support_f35.assert_count(
  $$SELECT count(*) FROM public.contracting_events
    WHERE id = '35070000-0000-4000-8000-000000000105'::uuid$$,
  0, 'ordinal overflow creates no event'
);
COMMIT;

RESET SESSION AUTHORIZATION;

SELECT test_support_f35.assert_text(
  $$SELECT last_ordinal::text FROM public.contracting_item_ordinal_counters
    WHERE contracting_id = '35040000-0000-4000-8000-000000000001'::uuid$$,
  '3', 'invalid quantity does not move allocator'
);
SELECT test_support_f35.assert_text(
  $$SELECT last_ordinal::text FROM public.contracting_item_ordinal_counters
    WHERE contracting_id = '35040000-0000-4000-8000-000000000002'::uuid$$,
  '2147483647', 'ordinal overflow does not wrap allocator'
);
