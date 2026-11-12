"""Baixa a temperatura máxima diária do ERA5-Land (Copernicus CDS) para uma área.

Uso (na raiz do repositório):
    python3 ferramentas/baixar_era5land.py --saida dados/brutos/era5land/rj \
        --anos 2016-2025 --area -20.6 -45.0 -23.5 -40.8

Fonte: "ERA5-Land post-processed daily statistics" (derived-era5-land-daily-statistics),
máxima diária da temperatura do ar a 2 m, dia civil no fuso UTC−3 (Brasília).
Requer: pip install cdsapi, e a chave pessoal do CDS na variável de ambiente
CDSAPI_KEY (no GitHub, um "secret" com esse nome). Cada ano vira um arquivo
<ano>.nc; arquivos já baixados são reaproveitados. Se o CDS recusar um ano
inteiro, o ano é baixado mês a mês.
"""
import argparse
import os
import sys
import time
import zipfile

import cdsapi

DATASET = "derived-era5-land-daily-statistics"


def pedido(ano, meses, area):
    return {
        "variable": ["2m_temperature"],
        "year": str(ano),
        "month": [f"{m:02d}" for m in meses],
        "day": [f"{d:02d}" for d in range(1, 32)],
        "daily_statistic": "daily_maximum",
        "time_zone": "utc-03:00",
        "frequency": "1_hourly",
        "area": area,  # norte, oeste, sul, leste
    }


def desempacotar(arq):
    """O CDS às vezes entrega um zip com o .nc dentro; deixa só o .nc."""
    if not zipfile.is_zipfile(arq):
        return [arq]
    pasta = os.path.dirname(arq)
    with zipfile.ZipFile(arq) as z:
        nomes = [n for n in z.namelist() if n.endswith(".nc")]
        base = os.path.splitext(arq)[0]
        saidas = []
        for i, n in enumerate(nomes):
            destino = f"{base}_{i}.nc" if len(nomes) > 1 else base + ".nc"
            with z.open(n) as src, open(destino + ".tmp", "wb") as dst:
                dst.write(src.read())
            os.replace(destino + ".tmp", destino)
            saidas.append(destino)
    if arq not in saidas:
        os.remove(arq)
    return saidas


def baixar(cliente, req, destino, tentativas=3):
    for t in range(1, tentativas + 1):
        try:
            tmp = destino + ".part"
            cliente.retrieve(DATASET, req, tmp)
            os.replace(tmp, destino)
            return True
        except Exception as e:  # noqa: BLE001 — registra e tenta de novo
            print(f"  tentativa {t} falhou: {e}", flush=True)
            time.sleep(30 * t)
    return False


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--saida", required=True)
    ap.add_argument("--anos", default="2016-2025")
    ap.add_argument("--area", nargs=4, type=float, required=True, metavar=("N", "O", "S", "L"))
    a = ap.parse_args()
    chave = os.environ.get("CDSAPI_KEY", "").strip()
    if not chave:
        sys.exit("Falta a chave do Copernicus CDS: defina CDSAPI_KEY (no GitHub: Settings → Secrets → Actions).")
    cliente = cdsapi.Client(url=os.environ.get("CDSAPI_URL", "https://cds.climate.copernicus.eu/api"),
                            key=chave, quiet=True, progress=False)
    ini, fim = (int(x) for x in a.anos.split("-"))
    os.makedirs(a.saida, exist_ok=True)
    for ano in range(ini, fim + 1):
        destino = os.path.join(a.saida, f"{ano}.nc")
        if os.path.exists(destino) or any(f.startswith(f"{ano}_") and f.endswith(".nc") for f in os.listdir(a.saida)):
            print(f"{ano}: já baixado", flush=True)
            continue
        t0 = time.time()
        print(f"{ano}: pedindo o ano inteiro…", flush=True)
        if baixar(cliente, pedido(ano, range(1, 13), a.area), destino):
            desempacotar(destino)
        else:
            print(f"{ano}: baixando mês a mês", flush=True)
            for m in range(1, 13):
                dm = os.path.join(a.saida, f"{ano}_{m:02d}.nc")
                if os.path.exists(dm):
                    continue
                if not baixar(cliente, pedido(ano, [m], a.area), dm):
                    sys.exit(f"Não foi possível baixar {ano}-{m:02d}.")
                desempacotar(dm)
        print(f"{ano}: ok ({time.time() - t0:.0f} s)", flush=True)


if __name__ == "__main__":
    main()
