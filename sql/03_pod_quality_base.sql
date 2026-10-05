-- Avaliação do comprovante de entrega (POD), uma linha por pacote.
--
-- pod_tier <= 0 significa que o POD não foi avaliado. Quando o pacote tem mais
-- de uma avaliação, fica a válida de menor tier.
--
-- check_flags é uma máscara de bits com os pontos sinalizados na avaliação:
--   1  qualidade da imagem
--   2  pacote não aparece na foto
--   4  etiqueta ilegível
--   8  localização fora do endereço
--   16 sem comprovante do recebedor

drop table if exists analytics.pod_quality_base;

create table analytics.pod_quality_base as
with ranked as (
    select
        tracking_number,
        pod_tier,
        coalesce(check_flags, 0) as check_flags,
        row_number() over (
            partition by tracking_number
            order by case when pod_tier > 0 then 0 else 1 end, pod_tier
        ) as rn
    from logistics.pod_evaluations
)

select
    tracking_number,
    pod_tier,
    case when pod_tier > 0 then 1 else 0 end as is_evaluated,
    case when bitwise_and(check_flags, 1)  <> 0 then 1 else 0 end as flag_image_quality,
    case when bitwise_and(check_flags, 2)  <> 0 then 1 else 0 end as flag_parcel,
    case when bitwise_and(check_flags, 4)  <> 0 then 1 else 0 end as flag_label,
    case when bitwise_and(check_flags, 8)  <> 0 then 1 else 0 end as flag_location,
    case when bitwise_and(check_flags, 16) <> 0 then 1 else 0 end as flag_receipt
from ranked
where rn = 1
;
