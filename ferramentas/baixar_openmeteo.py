"""Máximas diárias de temperatura do ar (ERA5-Land) a partir do bucket público do Open-Meteo.

Sem conta e sem chave: o Open-Meteo publica o ERA5-Land (ECMWF/Copernicus) no AWS Open
Data (s3://openmeteo, licença CC BY 4.0), em arquivos .om com leitura parcial. Lemos só a
janela da área pedida, hora a hora, e calculamos a máxima de cada dia civil em UTC−3.

Estrutura do bucket (data/copernicus_era5_land/temperature_2m/):
  year_AAAA.om   anos completos até 2021: matriz (lat 1801, lon 3600, horas), grade 0,1°
                 com a linha 0 em −90° e a coluna 0 em −180°
  chunk_N.om     anos recentes: blocos de 504 horas; o bloco N começa em N × 504 h (Unix)

Uso:
    python ferramentas/baixar_openmeteo.py --saida dados/brutos/era5land/rj \
        --anos 2016-2025 --area -20.6 -45.0 -23.5 -40.8      # norte oeste sul leste
Grava <saida>/tmax_AAAA.nc (variável tmax, °C; dimensões time, lat, lon) por ano;
pula anos já gravados.
"""
import argparse
import datetime as dt
import os

import fsspec
import numpy as np
from netCDF4 import Dataset
from omfiles import OmFileReader

BASE = "s3://openmeteo/data/copernicus_era5_land/temperature_2m"
PASSO = 0.1
HORAS_BLOCO = 504
FUSO = -3  # horas em relação ao UTC (dia civil no Brasil)


def abrir(nome):
    return OmFileReader(fsspec.open(f"blockcache::{BASE}/{nome}",
                                    s3={"anon": True, "default_block_size": 1 << 20}))


def janela(area):
    norte, oeste, sul, leste = area
    i0, i1 = int(np.floor((sul + 90) / PASSO)), int(np.ceil((norte + 90) / PASSO)) + 1
    j0, j1 = int(np.floor((oeste + 180) / PASSO)), int(np.ceil((leste + 180) / PASSO)) + 1
    return i0, i1, j0, j1


def horas_ano(ano, i0, i1, j0, j1):
    """Matriz (lat, lon, horas) de ano-01-01 00 UTC até (ano+1)-01-01 00 UTC + 3 h."""
    ini = dt.datetime(ano, 1, 1, tzinfo=dt.timezone.utc)
    fim = dt.datetime(ano + 1, 1, 1, tzinfo=dt.timezone.utc) + dt.timedelta(hours=-FUSO)
    t0, t1 = int(ini.timestamp() // 3600), int(fim.timestamp() // 3600)
    partes, t = [], t0
    while t < t1:
        a = dt.datetime.fromtimestamp(t * 3600, dt.timezone.utc).year
        if a <= 2021:
            # arquivo anual: índice de tempo = horas desde o início do ano
            ia = int(dt.datetime(a, 1, 1, tzinfo=dt.timezone.utc).timestamp() // 3600)
            fa = int(dt.datetime(a + 1, 1, 1, tzinfo=dt.timezone.utc).timestamp() // 3600)
            ate = min(t1, fa)
            with abrir(f"year_{a}.om") as r:
                partes.append(np.asarray(r[i0:i1, j0:j1, (t - ia):(ate - ia)], dtype="float32"))
        else:
            n = t // HORAS_BLOCO
            ib, fb = n * HORAS_BLOCO, (n + 1) * HORAS_BLOCO
            ate = min(t1, fb)
            with abrir(f"chunk_{n}.om") as r:
                partes.append(np.asarray(r[i0:i1, j0:j1, (t - ib):(ate - ib)], dtype="float32"))
        t = ate
    return np.concatenate(partes, axis=2)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--saida", required=True)
    ap.add_argument("--anos", default="2016-2025")
    ap.add_argument("--area", nargs=4, type=float, required=True, metavar=("NORTE", "OESTE", "SUL", "LESTE"))
    a = ap.parse_args()
    os.makedirs(a.saida, exist_ok=True)
    ini, fim = (int(x) for x in a.anos.split("-"))
    i0, i1, j0, j1 = janela(a.area)
    lat = -90 + PASSO * np.arange(i0, i1)
    lon = -180 + PASSO * np.arange(j0, j1)
    print(f"janela: {i1 - i0} × {j1 - j0} células (lat {lat[0]:.1f} a {lat[-1]:.1f}, lon {lon[0]:.1f} a {lon[-1]:.1f})", flush=True)
    for ano in range(ini, fim + 1):
        destino = os.path.join(a.saida, f"tmax_{ano}.nc")
        if os.path.exists(destino):
            print("já existe:", destino, flush=True)
            continue
        t = dt.datetime.now()
        h = horas_ano(ano, i0, i1, j0, j1)
        if np.nanmedian(h) > 200:
            h = h - 273.15
        dias = (dt.date(ano + 1, 1, 1) - dt.date(ano, 1, 1)).days
        h = h[:, :, -FUSO:-FUSO + 24 * dias]          # dia civil em UTC−3: 03 h a 03 h UTC
        with np.errstate(all="ignore"):
            tmax = np.nanmax(h.reshape(h.shape[0], h.shape[1], dias, 24), axis=3)
        with Dataset(destino, "w") as nc:
            nc.createDimension("time", dias)
            nc.createDimension("lat", len(lat))
            nc.createDimension("lon", len(lon))
            vt = nc.createVariable("time", "i4", ("time",))
            vt.units = f"days since {ano}-01-01"
            vt.calendar = "standard"
            vt[:] = np.arange(dias)
            vy = nc.createVariable("lat", "f4", ("lat",)); vy.units = "degrees_north"; vy[:] = lat
            vx = nc.createVariable("lon", "f4", ("lon",)); vx.units = "degrees_east"; vx[:] = lon
            v = nc.createVariable("tmax", "f4", ("time", "lat", "lon"), zlib=True, fill_value=np.float32(np.nan))
            v.units = "degC"
            v.long_name = "Máxima diária da temperatura do ar a 2 m (ERA5-Land via Open-Meteo), dia em UTC-3"
            v[:] = np.transpose(tmax, (2, 0, 1))
        terra = np.isfinite(tmax[:, :, 0])
        print(f"{ano}: {dias} dias, {terra.sum()} células de terra, máxima mediana {np.nanmedian(tmax):.1f} °C "
              f"({(dt.datetime.now() - t).total_seconds() / 60:.1f} min)", flush=True)


if __name__ == "__main__":
    main()
