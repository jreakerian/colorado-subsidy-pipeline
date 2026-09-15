-- Orphan geo_key values in fct_crimes that have no matching dim_geography row.
-- Zero rows = pass.
select fc.geo_key
from COLORADO_CRIME_DB_PROD.gold.fct_crimes as fc
left join COLORADO_CRIME_DB_PROD.gold.dim_geography as dg
    on fc.geo_key = dg.geo_key
where fc.geo_key is not null
  and dg.geo_key is null
group by fc.geo_key