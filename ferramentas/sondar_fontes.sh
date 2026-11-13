#!/usr/bin/env bash
# Sondagem das fontes socioeconômicas por pequena área (América Latina) — rodada 3.
set -u
mkdir -p /tmp/sonda && cd /tmp/sonda
python3 -m venv /tmp/v && . /tmp/v/bin/activate && pip install -q pandas xlrd pyshp playwright && python -m playwright install --with-deps chromium >/dev/null 2>&1
echo "===== COLÔMBIA"
curl -sL --max-time 900 -o col.zip "https://www.dane.gov.co/files/geoportal-provisional/SHP_VULNRB_IPMxMZ.zip"; ls -la col.zip; unzip -l col.zip | head -20
unzip -o -q col.zip -d col && python - <<'PY'
import shapefile,glob
for f in glob.glob('col/**/*.shp',recursive=True):
    r=shapefile.Reader(f); print(f, len(r), r.shapeTypeName); print([x[0] for x in r.fields[1:]])
    for i in range(3): print(r.record(i).as_dict())
PY
echo "===== MÉXICO IMU"
curl -sL --max-time 300 -o imu.zip "https://conapo.segob.gob.mx/work/models/CONAPO/Datos_Abiertos/Marginacion/IMU_2020.zip" && unzip -o -q imu.zip && python - <<'PY'
import pandas as pd
x=pd.ExcelFile('IMU_2020.xls');print(x.sheet_names)
for s in x.sheet_names[:3]:
  d=pd.read_excel(x,s,nrows=4);print(s);print(d.to_string())
PY
echo "===== MÉXICO INEGI via navegador"
python - <<'PY'
from playwright.sync_api import sync_playwright
url="https://www.inegi.org.mx/contenidos/productos/prod_serv/contenidos/espanol/bvinegi/productos/geografia/marcogeo/889463807469/09_ciudaddemexico.zip"
with sync_playwright() as p:
    b=p.chromium.launch(); c=b.new_context(accept_downloads=True); pg=c.new_page()
    try:
        pg.goto("https://www.inegi.org.mx/app/biblioteca/ficha.html?upc=889463807469", timeout=60000); pg.wait_for_timeout(8000)
        print("titulo:", pg.title())
        r=c.request.get(url, timeout=120000); print("status", r.status, r.headers.get("content-type"), len(r.body()))
    except Exception as e: print("erro", e)
    b.close()
PY
echo "===== edf-org"
git clone -q --filter=blob:none --no-checkout https://github.com/edf-org/mexico-oilgas-hia-data /tmp/edf && cd /tmp/edf && git ls-tree -r -l HEAD 05_Misc | head -30; cat .gitattributes 2>/dev/null | head
