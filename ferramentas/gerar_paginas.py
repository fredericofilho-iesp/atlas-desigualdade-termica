"""Gera as páginas HTML do atlas a partir de um só molde.

Uso (na raiz do repositório):  python3 ferramentas/gerar_paginas.py

Os textos ficam em js/i18n.js (inglês, português, espanhol). O HTML sai
com o texto em inglês, que é o que aparece sem JavaScript e o que os
buscadores leem; js/i18n.js troca para o idioma escolhido.
"""
import json
import os
import re
import subprocess

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def carregar_ingles():
    """Lê o dicionário inglês de js/i18n.js usando o Node, para não duplicar textos."""
    js = (
        "global.window={};global.document={addEventListener(){}};"
        "global.location={search:''};global.navigator={languages:['en']};"
        f"require({json.dumps(os.path.join(RAIZ, 'js', 'i18n.js'))});"
        "process.stdout.write(JSON.stringify(window.AtlasI18n._dicionario.en));"
    )
    return json.loads(subprocess.check_output(["node", "-e", js]))


EN = carregar_ingles()


def tx(chave, tag="span", attrs=""):
    return f'<{tag} data-i18n="{chave}"{attrs}>{EN[chave]}</{tag}>'


NAV = [
    ("", "nav.home", False),
    ("rio/", "nav.rio", False),
    ("estado-rj/", "nav.rj", False),
    ("brasil/", "nav.br", True),
    ("america-latina/", "nav.la", True),
    ("metodologia/", "nav.method", False),
]


def topo(prefixo, atual):
    itens = []
    for href, chave, em_breve in NAV:
        cur = ' aria-current="page"' if href == atual else ""
        destino = prefixo + href if (prefixo + href) else "./"
        nota = f' <span class="em-breve" data-i18n="nav.soon">{EN["nav.soon"]}</span>' if em_breve else ""
        itens.append(
            f'<li><a href="{destino}" data-nav="{destino}"{cur}>'
            f'<span data-i18n="{chave}">{EN[chave]}</span>{nota}</a></li>'
        )
    inicio = prefixo or "./"
    return f"""<header class="topo">
  <div class="topo-linha">
    <div>
      <p class="marca"><a href="{inicio}" data-nav="{inicio}" data-i18n="site.title">{EN["site.title"]}</a></p>
      <p class="sub" data-i18n="site.subtitle">{EN["site.subtitle"]}</p>
    </div>
    <div class="idioma">
      <label for="idioma" data-i18n="lang.label">{EN["lang.label"]}</label>
      <select id="idioma"><option value="en">English</option><option value="pt">Português</option><option value="es">Español</option></select>
    </div>
  </div>
  <nav data-i18n-attr="aria-label:nav.label" aria-label="{EN["nav.label"]}"><ul class="escalas">
    {"".join(itens)}
  </ul></nav>
</header>"""


def rodape():
    return f'<footer class="rodape" data-i18n="footer">{EN["footer"]}</footer>'


def cabeca(prefixo, titulo_chave, mapa=False):
    titulo = (EN[titulo_chave] + " · " if titulo_chave else "") + EN["site.title"]
    css_mapa = '<link rel="stylesheet" href="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.css">\n' if mapa else ""
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{titulo}</title>
<meta name="description" content="{EN['site.title']}: {EN['site.subtitle'].lower()}.">
<link rel="alternate" hreflang="en" href="?">
<link rel="alternate" hreflang="pt" href="?lang=pt">
<link rel="alternate" hreflang="es" href="?lang=es">
{css_mapa}<link rel="stylesheet" href="{prefixo}css/atlas.css">
<script src="{prefixo}js/i18n.js"></script>
</head>"""


ESCALAS = {
    "rio": dict(chave="rio", centro=[-43.45, -22.92], zoom=10, zoomMinimo=8, espessuraContorno=1,
                painelCalorRenda="../dados/processados/rio/calor_renda.json",
                painelArvores="../dados/processados/rio/arborizacao_resumo.json",
                painelGrupos="../dados/processados/rio/exposicao_grupos.json"),
    "estado-rj": dict(chave="rj", centro=[-42.65, -22.25], zoom=7.2, zoomMinimo=5, espessuraContorno=2.2),
    "brasil": dict(chave="br", centro=[-53.5, -14.5], zoom=3.4, zoomMinimo=2.5, espessuraContorno=1.6),
    "america-latina": dict(chave="la", centro=[-72, -14], zoom=2.4, zoomMinimo=1.5, espessuraContorno=1.6),
}


def pagina_mapa(slug, c):
    k = c["chave"]
    config = dict(c, escala=slug, manifesto=f"../dados/processados/{slug}/camada.json")
    return f"""{cabeca("../", k + ".title", mapa=True)}
<body data-i18n-titulo="{k}.title">
{topo("../", slug + "/")}
<main class="layout">
  <aside class="painel">
    {tx(k + ".title", "h1")}
    {tx(k + ".desc", "p", ' class="status"')}
    <label for="indicador" data-i18n="map.indicator">{EN["map.indicator"]}</label>
    <select id="indicador" disabled><option>{EN["map.loading"]}</option></select>
    <p id="status-camada" class="status" role="status">{EN["map.loadingLayer"]}</p>
    <div id="ficha" class="ficha" aria-live="polite">{tx("map.clickHint", "p", ' class="status"')}</div>
    <section id="painel-desigualdade" class="desigualdade" aria-live="polite" hidden></section>
    <section id="painel-arvores" class="desigualdade" aria-live="polite" hidden></section>
    <section id="painel-grupos" class="desigualdade" aria-live="polite" hidden></section>
    {tx(k + ".notice", "div", ' class="aviso"')}
    {tx("map.sourcesTitle", "h2")}
    <p class="status">{tx(k + ".sources")} {tx("map.detailsIn")}</p>
  </aside>
  <section class="caixa-mapa" data-i18n-attr="aria-label:map.ariaInteractive" aria-label="{EN["map.ariaInteractive"]}">
    <div class="cabeca-mapa">{tx(k + ".title", "strong")}<span class="badge" id="badge-mapa" data-i18n="map.badgeBasemap">{EN["map.badgeBasemap"]}</span></div>
    <div id="mapa" role="region" data-i18n-attr="aria-label:map.ariaNavigable" aria-label="{EN["map.ariaNavigable"]}"></div>
    <div id="legenda" class="legenda" hidden></div>
  </section>
</main>
{rodape()}
<script>window.ATLAS_CONFIG = {json.dumps(config, ensure_ascii=False)};</script>
<script src="https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.js"></script>
<script src="../js/atlas.js"></script>
</body>
</html>
"""


CARTOES = [
    ("rio/", "nav.rio", "home.rio.d", "status.building", ""),
    ("estado-rj/", "nav.rj", "home.rj.d", "status.building", ""),
    ("brasil/", "nav.br", "home.br.d", "status.planned", " planejado"),
    ("america-latina/", "nav.la", "home.la.d", "status.planned", " planejado"),
]


def pagina_inicio():
    linhas = []
    for h, t, d, s, c in CARTOES:
        etiqueta = tx(s, "span", ' class="etiqueta' + c + '"')
        linhas.append('    <a class="cartao" href="' + h + '" data-nav="' + h + '">'
                      + etiqueta + tx(t, "h2") + tx(d, "p") + "</a>")
    cartoes = "\n".join(linhas)
    return f"""{cabeca("", None)}
<body>
{topo("", "")}
<main class="conteudo">
  {tx("home.title", "h1")}
  {tx("home.lead", "p", ' class="lead"')}
  <div class="cartoes">
{cartoes}
  </div>
  {tx("home.body", "div", ' class="texto"')}
</main>
{rodape()}
</body>
</html>
"""


def pagina_metodologia():
    return f"""{cabeca("../", "method.title")}
<body data-i18n-titulo="method.title">
{topo("../", "metodologia/")}
<main class="conteudo texto">
  {tx("method.title", "h1")}
  {tx("method.body", "div")}
</main>
{rodape()}
</body>
</html>
"""


def gravar(caminho, html):
    caminho = os.path.join(RAIZ, caminho)
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    with open(caminho, "w", encoding="utf-8") as f:
        f.write(re.sub(r"[ \t]+\n", "\n", html))


for slug, c in ESCALAS.items():
    gravar(f"{slug}/index.html", pagina_mapa(slug, c))
gravar("index.html", pagina_inicio())
gravar("metodologia/index.html", pagina_metodologia())
print("Páginas geradas.")
