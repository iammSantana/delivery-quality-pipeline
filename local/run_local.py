"""
Roda o pipeline em DuckDB com os dados fictícios de seed.sql.

As queries em sql/ estão em Trino/Presto; o sqlglot converte pro dialeto do
DuckDB antes de executar. No fim roda algumas checagens básicas.

    pip install -r requirements.txt
    python local/run_local.py
"""
from pathlib import Path

import duckdb
import sqlglot

ROOT = Path(__file__).resolve().parent.parent
SQL_DIR = ROOT / "sql"


def run_trino_file(con, path):
    for stmt in sqlglot.transpile(path.read_text(encoding="utf-8"), read="trino", write="duckdb"):
        con.execute(stmt)


def one(con, query):
    row = con.execute(query).fetchone()
    return row[0] if row else None


def check(con):
    errors = []

    def expect(name, got, want):
        if got != want:
            errors.append(f"{name}: esperado {want!r}, veio {got!r}")

    # 1 linha por shipment, sem cross docking e sem pedido sem data
    expect("shipments", one(con, "select list(shipment_id order by shipment_id) from analytics.quality_analysis_base"),
           ["BR0001", "BR0002", "BR0003", "BR0004", "BR0007", "BR0008"])

    expect("ultima entrega", one(con, "select driver_id from analytics.delivery_quality_base where shipment_id = 'BR0001'"), 102)
    expect("data no fuso de SP", str(one(con, "select delivered_date from analytics.delivery_quality_base where shipment_id = 'BR0002'")), "2026-03-09")
    expect("frota propria", one(con, "select regional from analytics.delivery_quality_base where shipment_id = 'BR0003'"), "Frota Propria")
    expect("estacao sem regional", one(con, "select regional from analytics.delivery_quality_base where shipment_id = 'BR0004'"), "Sem regional")
    expect("telefone", one(con, "select driver_phone from analytics.delivery_quality_base where shipment_id = 'BR0001'"), "5511912345678")
    expect("telefone vazio", one(con, "select driver_phone from analytics.delivery_quality_base where shipment_id = 'BR0004'"), None)

    expect("motoristas na base", one(con, "select count(*) from analytics.driver_quality_base"), 6)
    expect("sem historico", one(con, "select driver_status from analytics.driver_quality_base where driver_id = 101"), "SEM HISTORICO")
    expect("inativo", one(con, "select driver_status from analytics.driver_quality_base where driver_id = 102"), "INATIVO")
    expect("suspenso", one(con, "select driver_status from analytics.driver_quality_base where driver_id = 104"), "SUSPENSO")
    expect("desempate log_id", one(con, "select driver_status from analytics.driver_quality_base where driver_id = 106"), "DESLIGADO")

    expect("pod menor tier valido", one(con, """
        select (pod_tier, flag_image_quality, flag_parcel, flag_label)
        from analytics.pod_quality_base where tracking_number = 'BR0001'
    """), (1, 1, 0, 1))
    expect("pod nao avaliado", one(con, "select is_evaluated from analytics.pod_quality_base where tracking_number = 'BR0003'"), 0)
    expect("flags 8 + 16", one(con, "select (flag_location, flag_receipt) from analytics.pod_quality_base where tracking_number = 'BR0002'"), (1, 1))

    expect("cep com zero a esquerda", one(con, "select zipcode_risk from analytics.quality_analysis_base where shipment_id = 'BR0001'"), "Alto risco")
    expect("cep sem risco", one(con, "select zipcode_risk from analytics.quality_analysis_base where shipment_id = 'BR0002'"), "Comum")
    expect("semana 31/12", one(con, "select week_label from analytics.quality_analysis_base where shipment_id = 'BR0007'"), "2026 W53")
    expect("semana 01/01", one(con, "select week_label from analytics.quality_analysis_base where shipment_id = 'BR0008'"), "2026 W53")

    return errors


def main():
    con = duckdb.connect()
    con.execute("set timezone = 'UTC'")
    con.execute((ROOT / "local" / "seed.sql").read_text(encoding="utf-8"))

    for path in sorted(SQL_DIR.glob("*.sql")):
        run_trino_file(con, path)
        print(f"ok  {path.name}")

    errors = check(con)
    if errors:
        print("\nfalhou:")
        for e in errors:
            print(" -", e)
        raise SystemExit(1)

    print("\ntodas as checagens passaram\n")
    print(con.sql("select * from analytics.quality_analysis_base order by shipment_id"))


if __name__ == "__main__":
    main()
