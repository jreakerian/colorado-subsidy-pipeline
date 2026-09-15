-- Businesses with out-of-bounds composite tier values.
-- Valid range is 1 (Basic Review) through 4 (Maximum Subsidy).
-- Businesses with no county match are excluded upstream (composite_tier > 0 filter).
-- Zero rows = pass.
select entity_id, composite_tier
from COLORADO_CRIME_DB_PROD.gold.fct_business_subsidy_tiers
where composite_tier not between 1 and 4