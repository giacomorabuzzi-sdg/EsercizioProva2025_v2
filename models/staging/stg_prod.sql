{% set staging_mode = var('time', 'T0') %}
{% set seed_name = 'products_t0' %}

{% if staging_mode == 'T1' %}
    {% set seed_name = 'products_t1' %}
{% endif %}

-- Recupera la relazione (tabella) sorgente in una variabile per riutilizzo
{% set source_relation = source('negozio', seed_name) %}

-- Controlla l'esistenza della colonna NEW_CATEGORY
{% set source_columns = adapter.get_columns_in_relation(source_relation) %}
{% set has_new_category = source_columns | selectattr('name', 'equalto', 'NEW_CATEGORY') | list | length > 0 %}


WITH products AS (
    SELECT * FROM {{ source_relation }}
)

SELECT 
    product_id,
    model_name,
    brand,
    category,
    list_price,
    color
        
    -- Includi NEW_CATEGORY solo se presente
    {% if has_new_category %}
    , new_category
    {% endif %}

FROM products