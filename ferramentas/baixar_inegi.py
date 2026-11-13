"""Baixa o Marco Geoestadístico 2020 do INEGI (AGEB urbanas, camada 00a).

O site do INEGI usa um verificador anti-robô que bloqueia curl/wget; um navegador
real (Chromium via Playwright) passa sem interação. Uso:
    python ferramentas/baixar_inegi.py dados/brutos/mex
Grava <pasta>/mg_2020_integrado.zip (só se ainda não existir).
"""
import os
import sys
from playwright.sync_api import sync_playwright

FICHA = "https://www.inegi.org.mx/app/biblioteca/ficha.html?upc=889463807469"
URL = ("https://www.inegi.org.mx/contenidos/productos/prod_serv/contenidos/espanol/bvinegi/"
       "productos/geografia/marcogeo/889463807469/mg_2020_integrado.zip")

pasta = sys.argv[1] if len(sys.argv) > 1 else "dados/brutos/mex"
os.makedirs(pasta, exist_ok=True)
destino = os.path.join(pasta, "mg_2020_integrado.zip")
if os.path.exists(destino) and os.path.getsize(destino) > 1e8:
    print("já existe:", destino)
    sys.exit(0)

with sync_playwright() as p:
    b = p.chromium.launch()
    c = b.new_context(accept_downloads=True)
    pg = c.new_page()
    pg.goto(FICHA, timeout=120000)
    pg.wait_for_timeout(8000)
    print("ficha:", pg.title())
    with pg.expect_download(timeout=0) as d:
        pg.evaluate("u => { const a = document.createElement('a'); a.href = u; document.body.appendChild(a); a.click(); }", URL)
    d.value.save_as(destino)
    b.close()
print("gravado:", destino, round(os.path.getsize(destino) / 1e6), "MB")
