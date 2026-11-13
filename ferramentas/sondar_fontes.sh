#!/usr/bin/env bash
# Sondagem das fontes socioeconômicas por pequena área (América Latina) — rodada 2.
set -u
mkdir -p /tmp/sonda && cd /tmp/sonda
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36"
cab() { echo "--- HEAD $1"; curl -sIL -A "$UA" --max-time 60 "$1" | grep -iE "^HTTP|content-length|content-type|location" | tail -4; }
echo "===== MÉXICO (geometria AGEB)"
B="https://www.inegi.org.mx/contenidos/productos/prod_serv/contenidos/espanol/bvinegi/productos/geografia/marcogeo/889463807469"
cab "$B/mg_2020_integrado.zip"
cab "$B/09_ciudaddemexico.zip"
cab "https://www.inegi.org.mx/contenidos/productos/prod_serv/contenidos/espanol/bvinegi/productos/geografia/marcogeo/794551132173/mg_2022_integrado.zip"
curl -sL -A "$UA" --max-time 60 "https://www.inegi.org.mx/app/api/productos/interna_v1/slcComponente/obtenComponentes?upc=889463807469" | head -c 3000; echo
curl -sL -A "$UA" --max-time 60 "https://www.inegi.org.mx/app/biblioteca/ficha.html?upc=889463807469" | grep -oiE "[^\"' ]*\.zip" | sort -u | head
echo "===== MÉXICO (IMU colunas)"
curl -sL --max-time 300 -o imu.zip "https://conapo.segob.gob.mx/work/models/CONAPO/Datos_Abiertos/Marginacion/IMU_2020.zip" && unzip -o -q imu.zip && python3 -c "
import subprocess;subprocess.run(['pip','install','-q','xlrd','pandas'])
import pandas as pd
x=pd.ExcelFile('IMU_2020.xls');print(x.sheet_names)
for s in x.sheet_names[:3]:
  d=pd.read_excel(x,s,nrows=5);print(s);print(d.to_string())
"
echo "===== COLÔMBIA"
for j in static/js/main.6ac7cce8.chunk.js static/js/2.08a9ba89.chunk.js; do
  echo "--- $j"; curl -sL --max-time 60 "https://www.dane.gov.co/files/geoportal-provisional/$j" -o j.js; ls -la j.js
  grep -oE "\"[^\"]*(IPM|ipm|VULNRB|MANZ|Manz|manz)[^\"]*\"" j.js | sort -u | head -40
  grep -oE "https?://[^\"' ]+\.(zip|rar|7z)" j.js | sort -u | head -40
done
echo "===== CHILE"
cab "https://www.ine.gob.cl/docs/default-source/censo-de-poblacion-y-vivienda/bbdd/censo-2017/csv/csv-personas.zip"
cab "https://redatam-ine.ine.cl/manuales/Microdatos_Censo_2017.zip"
curl -sL -A "$UA" --max-time 60 "https://www.ine.gob.cl/estadisticas/sociales/censos-de-poblacion-y-vivienda/censo-de-poblacion-y-vivienda" | grep -oiE "[^\"' ]*(\.zip|\.csv|microdato)[^\"' ]*" | sort -u | head -30
curl -sL -A "$UA" --max-time 60 "https://censo2024.ine.gob.cl/resultados/" | grep -oiE "[^\"' ]*(\.zip|\.csv|\.gpkg|manzana)[^\"' ]*" | sort -u | head -30
