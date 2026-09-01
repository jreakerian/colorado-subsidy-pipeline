-- Entities with != 1 current version (SCD2 invariant violation).
-- Zero rows = pass.
select
    entity_id,
    count(*) as current_version_count
from {{ ref('dim_business') }}
where is_current = true
group by entity_id
having count(*) != 1
