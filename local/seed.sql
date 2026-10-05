-- Dados fictícios (DuckDB) só pra rodar o pipeline local.
-- Cada linha cobre um caso que já deu problema ou que precisa ser garantido.

create schema if not exists logistics;
create schema if not exists ref;
create schema if not exists analytics;

create or replace table ref.stations (
    station_name varchar,
    regional varchar,
    sub_regional varchar
);

insert into ref.stations values
    ('HUB-SP-CENTRO', 'SP Capital', 'Centro'),
    ('HUB-SP-LESTE',  'SP Capital', 'Leste'),
    ('HUB-CPS',       'SP Interior', 'Campinas'),
    ('FP-GRU',        'SP Capital', 'Guarulhos');

create or replace table logistics.delivery_orders (
    shipment_id varchar,
    station_name varchar,
    station_type varchar,
    delivered_ts bigint,
    order_value decimal(12, 2),
    buyer_zipcode varchar,
    driver_id bigint,
    driver_name varchar,
    driver_phone varchar
);

insert into logistics.delivery_orders values
    -- duas tentativas de entrega: fica a mais recente (motorista 102)
    ('BR0001', 'HUB-SP-CENTRO', 'LAST_MILE', 1772445600, 89.90, '01310-100', 101, 'Ana Souza',  '(11) 98765-4321'),
    ('BR0001', 'HUB-SP-CENTRO', 'LAST_MILE', 1772532000, 89.90, '01310-100', 102, 'Bruno Lima', '11 91234-5678'),
    -- 01:30 UTC = 22:30 do dia anterior em SP
    ('BR0002', 'HUB-SP-LESTE',  'LAST_MILE', 1773106200, 45.00, '03510000',  103, 'Carla Dias', '5511955554444'),
    -- frota própria
    ('BR0003', 'FP-GRU',        'OWN_FLEET', 1772618400, 120.00, '07010-000', 104, 'Diego Reis', '11 94444-3333'),
    -- estação fora do cadastro de regionais
    ('BR0004', 'HUB-NOVO',      'LAST_MILE', 1772704800, 15.50, '13010-001', 105, 'Edu Nunes',  ''),
    -- cross docking não entra
    ('BR0005', 'XD-CAJAMAR',    'CROSS_DOCK', 1772704800, 60.00, '07750-000', 101, 'Ana Souza', '11987654321'),
    -- sem data de entrega não entra
    ('BR0006', 'HUB-CPS',       'LAST_MILE', null, 33.00, '13010-002', 101, 'Ana Souza', '11987654321'),
    -- virada de ano: 31/12/2026 em SP, semana ISO 2026 W53
    ('BR0007', 'HUB-CPS',       'LAST_MILE', 1798768800, 70.00, '13010-003', 106, 'Fabi Rocha', '19 99999-0000'),
    -- 01/01/2027 em SP, ainda semana ISO 2026 W53
    ('BR0008', 'HUB-CPS',       'LAST_MILE', 1798797600, 70.00, '13010-003', 106, 'Fabi Rocha', '19 99999-0000');

create or replace table logistics.drivers (
    driver_id bigint,
    agency_name varchar,
    agency_type varchar
);

insert into logistics.drivers values
    (101, 'Transportes Alfa', 'PARTNER'),
    (102, 'Transportes Alfa', 'PARTNER'),
    (103, 'Rota Beta',        'PARTNER'),
    (104, 'Frota Propria',    'OWN_FLEET'),
    (105, 'Rota Beta',        'PARTNER'),
    (106, 'Transportes Gama', 'PARTNER');

create or replace table logistics.driver_status_log (
    log_id bigint,
    created_ts bigint,
    driver_id bigint,
    status_code integer,
    sub_status_code integer,
    reason varchar
);

insert into logistics.driver_status_log values
    (1, 1767225600, 102, 4, null, 'cadastro novo'),
    (2, 1767312000, 102, 1, null, 'aprovado'),
    (3, 1769904000, 102, 2, 201,  'sem rotas há 30 dias'),
    (4, 1767225600, 103, 1, null, 'aprovado'),
    (5, 1767225600, 104, 1, null, 'aprovado'),
    (6, 1770000000, 104, 2, 305,  'documento vencido'),
    -- mesmo timestamp: desempata pelo log_id
    (7, 1767225600, 106, 1, null, 'aprovado'),
    (8, 1767225600, 106, 3, null, 'desligamento');
    -- 101 e 105 sem histórico de status

create or replace table logistics.pod_evaluations (
    tracking_number varchar,
    pod_tier integer,
    check_flags integer
);

insert into logistics.pod_evaluations values
    ('BR0001', 0, null),
    ('BR0001', 2, 4),
    ('BR0001', 1, 5),
    ('BR0002', 3, 24),
    ('BR0003', 0, 0),
    ('BR0007', 1, 0);

create or replace table ref.risk_zipcodes (
    zipcode bigint,
    risk_level varchar
);

insert into ref.risk_zipcodes values
    (1310100,  'Alto risco'),
    (13010003, 'Medio risco');
