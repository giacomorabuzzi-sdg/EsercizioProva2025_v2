{% set staging_mode = var('time', 'T0') %}
{% set seed_name = 'clients_t0' %}

{% if staging_mode == 'T1' %}
    {% set seed_name = 'clients_t1' %}
{% endif %}

-- La sorgente è definita dinamicamente, puntando a clients_t0 o clients_t1
{% set source_relation = source('negozio', seed_name) %}

WITH clients AS (
    SELECT * FROM {{ source_relation }}
)

SELECT 
    customer_id,
    name,
    email,
    city,
    member_since
FROM clients