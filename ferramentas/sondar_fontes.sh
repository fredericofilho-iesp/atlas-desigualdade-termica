#!/usr/bin/env bash
# Sondagem das fontes socioeconômicas por pequena área (América Latina). Só lista, não grava no repositório.
set -u
mkdir -p /tmp/sonda && cd /tmp/sonda
cab() { echo "--- HEAD $1"; curl -sIL --max-time 60 "$1" | grep -iE "^HTTP|content-length|content-type|location" | tail -4; }
zipls() { echo "--- ZIP $1"; curl -sL --max-time 900 -o f.zip "$1" && ls -la f.zip && (unzip -l f.zip | head -40); rm -f f.zip; }
pag() { echo "--- PAGE $1"; curl -sL --max-time 60 "$1" -o p.html; ls -la p.html; grep -oE "(https?:)?//[^\"' )]+|[A-Za-z0-9_./-]+\.(zip|rar|7z|json|js|gdb|shp)" p.html | sort -u | grep -viE "fonts|google|jquery|bootstrap|\.css" | head -60; }

echo "===== MÉXICO"
zipls "https://conapo.segob.gob.mx/work/models/CONAPO/Datos_Abiertos/Marginacion/IMU_2020.zip"
B="https://www.inegi.org.mx/contenidos/productos/prod_serv/contenidos/espanol/bvinegi/productos/geografia/marcogeo/889463807469"
cab "$B/mg_2020_integrado.zip"
cab "$B/09_ciudaddemexico.zip"
pag "https://www.inegi.org.mx/app/biblioteca/ficha.html?upc=889463807469"

echo "===== COLÔMBIA"
pag "https://www.dane.gov.co/files/geoportal-provisional/index.html"
for j in $(grep -oE "[A-Za-z0-9_./-]+\.(js|json)" p.html | grep -v -i jquery | sort -u | head -10); do
  u="https://www.dane.gov.co/files/geoportal-provisional/$j"; echo "--- JS $u"; curl -sL --max-time 60 "$u" | grep -oE "[^\"' ]*(IPM|ipm|VULNRB|MANZ|manz)[^\"' ]*" | sort -u | head -30; done
pag "https://geoportal.dane.gov.co/visipm/"
grep -oE "https?://[^\"' ]*rest/services[^\"' ]*" p.html | sort -u | head

echo "===== CHILE"
cab "https://opendata.arcgis.com/api/v3/datasets/6ed956450cfc4293b7d90df3ce3474e4_0/downloads/data?format=shp&spatialRefId=4326"
curl -sL --max-time 60 "https://hub.arcgis.com/api/v3/datasets/6ed956450cfc4293b7d90df3ce3474e4_0" | head -c 1500; echo
curl -sL --max-time 60 "https://www.arcgis.com/sharing/rest/content/items/6ed956450cfc4293b7d90df3ce3474e4?f=json" | head -c 1500; echo
