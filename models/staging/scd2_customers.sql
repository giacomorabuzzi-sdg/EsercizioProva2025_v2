{{ 
    config(
        materialized = 'incremental',
        unique_key = 'customer_update_id', 
        incremental_strategy = 'merge'
    ) 
}}

with source_data as (
    -- Seleziono tutti i record dalla tabella appropriata e genero la chiave surrogata
    select
        *,
        {{ dbt_utils.generate_surrogate_key(['customer_cd', 'last_update']) }} as customer_update_id
    from 
    {% if is_incremental() %}
    {{ source('negozio', 'customers_t1') }}
    {% else %}
    {{ source('negozio', 'customers_t0') }}
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
        on s.customer_update_id = t.customer_update_id
    where t.customer_update_id is null
),
{% endif %}

-- 2. Righe da INSERIRE (Nuovi o versioni aggiornate)
rows_to_insert as (
    select
        customer_update_id,
        customer_cd,
        name,
        email,
        city,
        member_since,
        last_update,
        is_deleted,
        current_timestamp() as dbt_updated_at,
        last_update as valid_from,
        null as valid_to,          -- La versione più recente è 'aperta'
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
        t.customer_update_id,
        t.customer_cd,
        t.name,
        t.email,
        t.city,
        t.member_since,
        t.last_update,
        t.is_deleted,
        t.dbt_updated_at,
        t.valid_from,
        s.last_update as valid_to, -- Usa il timestamp della nuova versione come 'valid_to'
        false as is_current        -- Contrassegna come record non più corrente
    from {{ this }} as t
    -- Unisci con i record sorgente modificati per trovare i record 'is_current = true' da chiudere
    inner join changed_records_source s
        on t.customer_cd = s.customer_cd
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