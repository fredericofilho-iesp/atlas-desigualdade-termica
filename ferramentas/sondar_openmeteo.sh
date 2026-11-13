#!/usr/bin/env bash
# Sondagem temporária do bucket público do Open-Meteo — rodada 2 (formato dos arquivos)
set -u
B=s3://openmeteo/data/copernicus_era5_land
aws s3 cp --no-sign-request $B/static/meta.json - ; echo
aws s3 ls --no-sign-request $B/temperature_2m/ | awk '{print $4}' | sed -n '1p;$p'
aws s3 ls --no-sign-request $B/temperature_2m/ | grep year_ | awk '{print $4}' | tr '\n' ' '; echo
aws s3 ls --no-sign-request $B/temperature_2m/ | grep chunk_ | awk '{print $4}' | sort -t_ -k2 -n | sed -n '1p;$p'
python3 -m venv /tmp/v && . /tmp/v/bin/activate && pip install -q omfiles fsspec s3fs numpy
python - <<'PY'
import fsspec, numpy as np, time
from omfiles import OmFileReader
for nome in ["year_2021.om", "chunk_1000.om"]:
    t=time.time()
    try:
        be=fsspec.open(f"blockcache::s3://openmeteo/data/copernicus_era5_land/temperature_2m/{nome}", s3={"anon":True,"default_block_size":65536})
        with OmFileReader(be) as r:
            print(nome, "shape", r.shape, "chunks", getattr(r,"chunks",None), "dtype", r.dtype, "nome", getattr(r,"name",None))
            try:
                print(" filhos:", [r.get_child_by_index(i).name for i in range(r.num_children)])
            except Exception as e: print(" filhos?", e)
            # janela pequena: tenta [lat, lon, tempo]
            s=r.shape
            if len(s)==3:
                sub=r[1000:1003, 1300:1303, 0:48]
                print(" amostra", np.round(sub[0,0,:12],2), "t=%.1fs"%(time.time()-t))
    except Exception as e: print(nome, "erro", repr(e)[:300])
PY
