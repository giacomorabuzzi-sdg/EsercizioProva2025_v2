{{ 
    config(
        materialized = 'incremental',
        unique_key = 'product_cd',
        incremental_strategy = 'merge'
    ) 
}}
with 

source as (
    select
        *
    {% if is_incremental() %}
    from {{ source('negozio', 'products_t1') }}
    {% else %}
    from {{ source('negozio', 'products_t0') }}
    {% endif %}
),

{% if is_incremental() %}
new_records as (
    select * from source
    MINUS
    select product_cd,
        model_name,
        brand,
        category,
        list_price,
        color,
        is_deleted from {{ this }}
),
{% endif %}

delta_calc as (
    select
        product_cd,
        model_name,
        brand,
        category,
        list_price,
        color,
        is_deleted

    from
    {% if is_incremental() %}
        new_records
    {% else %}
        source
    {% endif %}
),

final as (
    select
        {{ dbt_utils.generate_surrogate_key(['product_cd'])  }} as product_id,
        *,
        current_timestamp() as dbt_updated_at
    from delta_calc
)

select * from final