-- Businesses with out-of-bounds composite tier values.
-- 0 = Unranked (no county match) — intentionally retained in the output.
-- Valid range: 0 (Unranked) through 4 (Maximum Subsidy).
-- Zero rows = pass.
select entity_id, composite_tier
from {{ ref('fct_business_subsidy_tiers') }}
where composite_tier not between 0 and 4
