{{
    config(
        materialized='incremental',
        unique_key=['product_id'],
        incremental_strategy='merge'
    )
}}


{% set source_relation = ref('stg_prod') %}
{% set columns = adapter.get_columns_in_relation(source_relation) %}

-- Verifica se la colonna 'new_category' esiste nello staging
{% set has_new_category = 'NEW_CATEGORY' in columns | map(attribute='name') | list %}


-- T1: Nuovi dati (o dati potenzialmente aggiornati) in arrivo dallo staging
-- Questa CTE è sempre necessaria, indipendentemente dalla modalità.
WITH new_data AS (
    SELECT
        model_name,
        brand,
        -- Se la colonna NEW_CATEGORY esiste, usiamo COALESCE. Altrimenti, usiamo la colonna CATEGORY.
        {% if has_new_category %}
        COALESCE(new_category, category) AS category,
        {% else %}
        category,
        {% endif %}
        list_price,
        color,
        product_id,
        current_timestamp() AS change_date
        
    FROM {{ ref('stg_prod') }}
)



{% if is_incremental() %}

-- Modalità INCREMENTALE: Esegui il confronto (JOIN)
, current_data AS (
    SELECT
        model_name,
        model_brand AS brand, 
        model_category AS category,
        model_price AS list_price,
        model_color AS color,
        product_id,
        last_changed_date AS old_last_changed_date
    FROM {{ this }}
),

changes AS (
    SELECT
        t1.model_name AS new_model_name,
        t0.model_name AS old_model_name,
        t1.brand AS new_brand,
        t0.brand AS old_brand,
        t1.category AS new_category,
        t0.category AS old_category,
        t1.list_price AS new_list_price,
        t0.list_price AS old_list_price,
        t1.color AS new_color,
        t0.color AS old_color,
        t0.old_last_changed_date AS old_last_changed_date,
        COALESCE(t1.product_id, t0.product_id) AS product_id
    FROM new_data AS t1
    FULL JOIN current_data AS t0
        ON t1.product_id = t0.product_id
)

SELECT
    COALESCE(c.new_model_name, c.old_model_name) AS model_name,
    COALESCE(c.new_brand, c.old_brand) AS model_brand,
    COALESCE(c.new_category, c.old_category) AS model_category,
    COALESCE(c.new_list_price, c.old_list_price) AS model_price,
    COALESCE(c.new_color, c.old_color) AS model_color,
    c.product_id,
    
    CASE
        WHEN c.old_model_name IS NULL THEN 'Inserted'
        WHEN c.new_model_name IS NULL THEN 'Deleted'
        WHEN c.old_category != c.new_category
             THEN 'Updated'
        ELSE 'No Change'
    END AS record_status,
    
    CASE
        -- Se è un Inserted o Updated, usa il timestamp corrente.
        WHEN c.old_model_name IS NULL OR c.old_category != c.new_category THEN current_timestamp()
        -- Se è un Deleted o No Change, usa il timestamp ESISTENTE (old_last_changed_date).
        ELSE c.old_last_changed_date 
    END AS last_changed_date

FROM changes AS c

WHERE
    record_status IN ('Inserted', 'Updated', 'Deleted')

{% else %}

-- Modalità FULL REFRESH (Prima run): Nessun confronto.
SELECT
    model_name,
    brand AS model_brand,
    category AS model_category,
    list_price AS model_price,
    color AS model_color,
    product_id,
    'Inserted' AS record_status,
    change_date AS last_changed_date
FROM new_data

{% endif %}