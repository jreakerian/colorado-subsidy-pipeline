-- Businesses with out-of-bounds composite tier values.
-- Zero rows = pass.
select entity_id, composite_tier
from COLORADO_CRIME_DB_DEV.gold.fct_business_subsidy_tiers
where composite_tier not between 1 and 4