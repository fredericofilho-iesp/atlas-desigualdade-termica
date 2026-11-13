"""Métricas de calor extremo (temperatura do ar, ERA5-Land) para uma área grande.

Mesmo dado de ferramentas/baixar_openmeteo.py (espelho público do Open-Meteo no AWS
Open Data, sem conta), mas sem gravar as máximas diárias: para o Brasil e a América
Latina isso seriam gigabytes por ano. A área é lida em faixas de latitude, em paralelo,
e cada faixa acumula, célula a célula (grade de 0,1°):
  dias_30 … dias_38   dias por ano com máxima diária ≥ limiar (média dos anos)
  txx                 maior máxima do ano (média dos anos)
  tmax_quente         média das máximas diárias nos 3 meses consecutivos mais quentes de
                      cada célula (o "verão" de cada lugar, como no MODIS de R/21 e R/31)
  mes_quente          mês central desse trimestre
Dia civil em UTC−3 (aproximação razoável para a maior parte da região; no México e na
América Central o dia local começa 2–3 h depois, o que quase não muda a máxima diária).

Uso:
    python ferramentas/calor_grade_openmeteo.py --saida dados/brutos/era5land/latam_metricas.tif \
        --anos 2016-2025 --area 33 -118 -56 -34          # norte oeste sul leste
"""
import argparse
import datetime as dt
import os
import time
from concurrent.futures import ThreadPoolExecutor

import fsspec
import numpy as np
import rasterio
from omfiles import OmFileReader
from rasterio.transform import from_origin

BASE = "s3://openmeteo/data/copernicus_era5_land/temperature_2m"
PASSO = 0.1
HORAS_BLOCO = 504
FUSO = -3
LIMIARES = [30, 32, 35, 38]


def abrir(nome):
    return OmFileReader(fsspec.open(f"blockcache::{BASE}/{nome}",
                                    s3={"anon": True, "default_block_size": 4 << 20}))


def horas(ano, i0, i1, j0, j1):
    ini = dt.datetime(ano, 1, 1, tzinfo=dt.timezone.utc)
    fim = dt.datetime(ano + 1, 1, 1, tzinfo=dt.timezone.utc) + dt.timedelta(hours=-FUSO)
    t0, t1 = int(ini.timestamp() // 3600), int(fim.timestamp() // 3600)
    partes, t = [], t0
    while t < t1:
        a = dt.datetime.fromtimestamp(t * 3600, dt.timezone.utc).year
        if a <= 2021:
            ia = int(dt.datetime(a, 1, 1, tzinfo=dt.timezone.utc).timestamp() // 3600)
            fa = int(dt.datetime(a + 1, 1, 1, tzinfo=dt.timezone.utc).timestamp() // 3600)
            ate, nome, base = min(t1, fa), f"year_{a}.om", ia
        else:
            n = t // HORAS_BLOCO
            ate, nome, base = min(t1, (n + 1) * HORAS_BLOCO), f"chunk_{n}.om", n * HORAS_BLOCO
        for tentativa in range(4):
            try:
                with abrir(nome) as r:
                    partes.append(np.asarray(r[i0:i1, j0:j1, (t - base):(ate - base)], dtype="float32"))
                break
            except Exception as e:  # rede instável: tenta de novo
                if tentativa == 3:
                    raise
                print(f"  repetindo {nome} ({e!r})", flush=True)
                time.sleep(5 * (tentativa + 1))
        t = ate
    h = np.concatenate(partes, axis=2)
    if np.nanmedian(h) > 200:
        h = h - 273.15
    return h


def faixa(args):
    i0, i1, j0, j1, anos = args
    nl, nc = i1 - i0, j1 - j0
    cont = {l: np.zeros((nl, nc), "float32") for l in LIMIARES}
    msum = np.zeros((12, nl, nc), "float64")
    mcnt = np.zeros((12, nl, nc), "int32")
    txx = np.zeros((nl, nc), "float64")
    terra = np.zeros((nl, nc), bool)
    for ano in anos:
        h = horas(ano, i0, i1, j0, j1)
        dias = (dt.date(ano + 1, 1, 1) - dt.date(ano, 1, 1)).days
        h = h[:, :, -FUSO:-FUSO + 24 * dias].reshape(nl, nc, dias, 24)
        with np.errstate(all="ignore"):
            d = np.nanmax(h, axis=3)                      # (lat, lon, dias)
        del h
        ok = np.isfinite(d)
        terra |= ok.any(axis=2)
        for l in LIMIARES:
            cont[l] += (np.where(ok, d, -99) >= l).sum(axis=2)
        with np.errstate(all="ignore"):
            txx += np.nan_to_num(np.nanmax(d, axis=2))
        mes = np.array([(dt.date(ano, 1, 1) + dt.timedelta(days=k)).month for k in range(dias)])
        for m in range(1, 13):
            s = d[:, :, mes == m]
            msum[m - 1] += np.nansum(s, axis=2)
            mcnt[m - 1] += np.isfinite(s).sum(axis=2)
    n = len(anos)
    with np.errstate(all="ignore"):
        mm = msum / mcnt                                  # média mensal das máximas
        tri = np.stack([np.nanmean(mm[[(m - 1) % 12, m, (m + 1) % 12]], axis=0) for m in range(12)])
        tri_f = np.where(np.isfinite(tri), tri, -np.inf)
        im = tri_f.argmax(axis=0)
        quente = np.take_along_axis(tri, im[None], axis=0)[0]
    out = {f"dias_{l}": cont[l] / n for l in LIMIARES}
    out["txx"] = txx / n
    out["tmax_quente"] = quente
    out["mes_quente"] = (im + 1).astype("float32")
    for k in out:
        out[k] = np.where(terra, out[k], np.nan).astype("float32")
    return i0, out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--saida", required=True)
    ap.add_argument("--anos", default="2016-2025")
    ap.add_argument("--area", nargs=4, type=float, required=True, metavar=("NORTE", "OESTE", "SUL", "LESTE"))
    ap.add_argument("--linhas", type=int, default=8, help="linhas de grade por faixa")
    ap.add_argument("--processos", type=int, default=6)
    a = ap.parse_args()
    if os.path.exists(a.saida):
        print("já existe:", a.saida)
        return
    ini, fim = (int(x) for x in a.anos.split("-"))
    anos = list(range(ini, fim + 1))
    norte, oeste, sul, leste = a.area
    I0, I1 = int(np.floor((sul + 90) / PASSO)), int(np.ceil((norte + 90) / PASSO)) + 1
    J0, J1 = int(np.floor((oeste + 180) / PASSO)), int(np.ceil((leste + 180) / PASSO)) + 1
    nl, nc = I1 - I0, J1 - J0
    print(f"grade: {nl} × {nc} células, {len(anos)} anos, faixas de {a.linhas} linhas", flush=True)
    nomes = [f"dias_{l}" for l in LIMIARES] + ["txx", "tmax_quente", "mes_quente"]
    total = {k: np.full((nl, nc), np.nan, "float32") for k in nomes}
    tarefas = [(i, min(i + a.linhas, I1), J0, J1, anos) for i in range(I0, I1, a.linhas)]
    t0 = time.time()
    with ThreadPoolExecutor(a.processos) as ex:
        for k, (i, out) in enumerate(ex.map(faixa, tarefas), 1):
            for n in nomes:
                total[n][i - I0:i - I0 + out[n].shape[0]] = out[n]
            if k % 10 == 0 or k == len(tarefas):
                print(f"  faixas {k}/{len(tarefas)} ({(time.time() - t0) / 60:.1f} min)", flush=True)
    os.makedirs(os.path.dirname(a.saida) or ".", exist_ok=True)
    # linha 0 da grade = sul; o GeoTIFF vai de norte para sul
    lat_top = -90 + PASSO * (I1 - 1) + PASSO / 2
    lon_left = -180 + PASSO * J0 - PASSO / 2
    with rasterio.open(a.saida, "w", driver="GTiff", height=nl, width=nc, count=len(nomes), dtype="float32",
                       crs="EPSG:4326", transform=from_origin(lon_left, lat_top, PASSO, PASSO),
                       nodata=np.nan, compress="deflate", predictor=3) as dst:
        for b, n in enumerate(nomes, 1):
            dst.write(total[n][::-1], b)
            dst.set_band_description(b, n)
    v = total["tmax_quente"]
    print(f"gravado {a.saida}: {np.isfinite(v).sum()} células de terra; tmax_quente mediana {np.nanmedian(v):.1f} °C; "
          f"dias_35 mediana {np.nanmedian(total['dias_35']):.1f} ({(time.time() - t0) / 60:.1f} min)", flush=True)


if __name__ == "__main__":
    main()
