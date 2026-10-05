-- Cadastro de motoristas + status atual (último registro do histórico).

drop table if exists analytics.driver_quality_base;

create table analytics.driver_quality_base as
with last_status as (
    select
        driver_id,
        status_code,
        sub_status_code,
        reason,
        created_ts,
        row_number() over (
            partition by driver_id
            order by created_ts desc, log_id desc
        ) as rn
    from logistics.driver_status_log
)

select
    d.driver_id,
    d.agency_name,
    case
        when d.agency_type = 'OWN_FLEET' then 'Frota Propria'
        else 'Parceiro'
    end as driver_category,
    case
        when s.driver_id is null then 'SEM HISTORICO'
        when s.status_code = 1 then 'ATIVO'
        when s.status_code = 2 and s.sub_status_code = 201 then 'INATIVO'
        when s.status_code = 2 then 'SUSPENSO'
        when s.status_code = 3 then 'DESLIGADO'
        when s.status_code = 4 then 'AGUARDANDO APROVACAO'
        else 'OUTRO'
    end as driver_status,
    s.reason as status_reason,
    date(from_unixtime(s.created_ts) at time zone 'America/Sao_Paulo') as status_date
from logistics.drivers d
-- rn = 1 fica no join: no where, o left join viraria inner e
-- motorista sem histórico sumiria da base
left join last_status s
    on s.driver_id = d.driver_id
   and s.rn = 1
;
