-- Base de entregas: uma linha por shipment, sempre a última entrega registrada.
-- Considera só bases de last mile e frota própria.

drop table if exists analytics.delivery_quality_base;

create table analytics.delivery_quality_base as
with orders as (
    select
        o.shipment_id,
        o.station_name,
        o.station_type,
        case
            when o.station_type = 'OWN_FLEET' then 'Frota Propria'
            else coalesce(s.regional, 'Sem regional')
        end as regional,
        s.sub_regional,
        o.delivered_ts,
        o.order_value,
        regexp_replace(o.buyer_zipcode, '[^0-9]', '') as zipcode_digits,
        o.driver_id,
        o.driver_name,
        regexp_replace(o.driver_phone, '[^0-9]', '') as phone_digits,
        row_number() over (
            partition by o.shipment_id
            order by o.delivered_ts desc
        ) as rn
    from logistics.delivery_orders o
    left join ref.stations s
        on s.station_name = o.station_name
    where o.station_type in ('LAST_MILE', 'OWN_FLEET')
      and o.delivered_ts is not null
)

select
    shipment_id,
    station_name,
    station_type,
    regional,
    sub_regional,
    date(from_unixtime(delivered_ts) at time zone 'America/Sao_Paulo') as delivered_date,
    order_value,
    -- CEP sempre com 8 dígitos (alguns sistemas perdem o zero à esquerda)
    lpad(nullif(zipcode_digits, ''), 8, '0') as buyer_zipcode,
    driver_id,
    driver_name,
    case
        when length(phone_digits) in (10, 11) then concat('55', phone_digits)
        else nullif(phone_digits, '')
    end as driver_phone
from orders
where rn = 1
;
