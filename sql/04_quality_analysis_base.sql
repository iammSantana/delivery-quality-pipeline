-- Base final: entrega + motorista + POD + risco do CEP.
-- É a tabela que alimenta o relatório.

drop table if exists analytics.quality_analysis_base;

create table analytics.quality_analysis_base as
with risk_zipcodes as (
    -- a tabela de risco pode guardar o CEP como número, então padroniza aqui
    select
        lpad(regexp_replace(cast(zipcode as varchar), '[^0-9]', ''), 8, '0') as zipcode,
        risk_level
    from ref.risk_zipcodes
),

joined as (
    select
        d.shipment_id,
        d.station_name,
        d.station_type,
        d.regional,
        d.sub_regional,
        d.delivered_date,
        -- semana ISO: year_of_week evita 01/01 cair na semana 53 do ano errado
        concat(
            cast(year_of_week(d.delivered_date) as varchar),
            ' W',
            lpad(cast(week(d.delivered_date) as varchar), 2, '0')
        ) as week_label,
        d.order_value,
        d.buyer_zipcode,
        d.driver_id,
        d.driver_name,
        d.driver_phone,
        drv.agency_name,
        drv.driver_category,
        drv.driver_status,
        drv.status_reason,
        pod.pod_tier,
        coalesce(pod.is_evaluated, 0) as pod_evaluated,
        pod.flag_image_quality,
        pod.flag_parcel,
        pod.flag_label,
        pod.flag_location,
        pod.flag_receipt,
        coalesce(rz.risk_level, 'Comum') as zipcode_risk,
        -- garantia contra duplicidade vinda de cadastro de motorista ou CEP repetido
        row_number() over (
            partition by d.shipment_id
            order by rz.risk_level desc nulls last
        ) as rn
    from analytics.delivery_quality_base d
    left join analytics.driver_quality_base drv
        on drv.driver_id = d.driver_id
    left join analytics.pod_quality_base pod
        on pod.tracking_number = d.shipment_id
    left join risk_zipcodes rz
        on rz.zipcode = d.buyer_zipcode
)

select
    shipment_id,
    station_name,
    station_type,
    regional,
    sub_regional,
    delivered_date,
    week_label,
    order_value,
    buyer_zipcode,
    driver_id,
    driver_name,
    driver_phone,
    agency_name,
    driver_category,
    driver_status,
    status_reason,
    pod_tier,
    pod_evaluated,
    flag_image_quality,
    flag_parcel,
    flag_label,
    flag_location,
    flag_receipt,
    zipcode_risk
from joined
where rn = 1
;
