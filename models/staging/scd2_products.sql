{{ 
    config(
        materialized = 'incremental',
        unique_key = 'multi_key',
        incremental_strategy = 'merge'
    ) 
}}

with source_data as (
    -- Seleziono tutti i record dalla tabella appropriata e genero la chiave surrogata
    select
        *,
        {{ dbt_utils.generate_surrogate_key(['product_cd','category', 'list_price', 'color','is_deleted']) }} as multi_key
    from 
    {% if is_incremental() %}
    {{ source('negozio', 'products_t1') }}
    {% else %}
    {{ source('negozio', 'products_t0') }}
    {% endif %}
),

{% if is_incremental() %}
-- 1. Identifica i record NUOVI o MODIFICATI nel set di dati sorgente
changed_records_source as (
    select
        s.*
    from source_data s
    -- Solo i record la cui 'customer_update_id' NON esiste già nel modello ({{ this }})
    left join {{ this }} as t
        on s.multi_key = t.multi_key
    where t.multi_key is null
),
{% endif %}

-- 2. Righe da INSERIRE (Nuovi o versioni aggiornate)
rows_to_insert as (
    select
        multi_key,
        product_cd,
        model_name,
        brand,
        category,
        list_price,
        color,
        is_deleted,
        current_timestamp() as dbt_updated_at,
        true as is_current         -- Contrassegna come record corrente
    from 
    {% if is_incremental() %}
        changed_records_source     -- In incrementale, inseriamo solo le righe modificate
    {% else %}
        source_data                -- In full-refresh, inseriamo tutto
    {% endif %}
),

{% if is_incremental() %}
-- 3. Righe da AGGIORNARE/CHIUDERE (Le vecchie versioni che devono essere contrassegnate come non più correnti)
rows_to_update as (
    select
        t.multi_key,
        t.product_cd,
        t.model_name,
        t.brand,
        t.category,
        t.list_price,
        t.color,
        t.is_deleted,
        t.dbt_updated_at,
        false as is_current        -- Contrassegna come record non più corrente
    from {{ this }} as t
    -- Unisci con i record sorgente modificati per trovare i record 'is_current = true' da chiudere
    inner join changed_records_source s
        on t.product_cd = s.product_cd
    where t.is_current = true
),
{% endif %}

final as (
    -- Combina i record da inserire e i record esistenti da aggiornare/chiudere
    select * from rows_to_insert
    
    {% if is_incremental() %}
    union all
    select * from rows_to_update
    {% endif %}
)

select * from final