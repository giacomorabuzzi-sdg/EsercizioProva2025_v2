{{ 
    config(
        materialized = 'incremental',
        unique_key = 'customer_cd',
        incremental_strategy = 'delete+insert',
    ) 
}}
with 

source as (
    select
        *
    {% if is_incremental() %}
    from {{ source('negozio', 'customers_t1') }}
    {% else %}
    from {{ source('negozio', 'customers_t0') }}
    {% endif %}
),

delta_calc as (
    select
        customer_cd,
        name,
        email,
        city,
        member_since,
        last_update,
        is_deleted
    from source
    {% if is_incremental() %}
    where last_update > (select max(last_update) from {{ this }})
    {% endif %}
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['customer_cd'])  }} as customer_id,
        *,
        current_timestamp() as dbt_updated_at
    from delta_calc
)

select * from final