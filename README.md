# Atlas Interativo de Desigualdade Térmica

Plataforma acadêmica aberta para explorar exposição ao calor e desigualdades socioespaciais em quatro escalas: município do Rio de Janeiro, estado do Rio de Janeiro, Brasil e América Latina.

Site: https://fredericofilho-iesp.github.io/atlas-desigualdade-termica/

## Estado atual — v0.3

- Estrutura com uma página por escala, mapas em **MapLibre GL JS** e mapa-base OpenFreeMap, gratuito e sem chave de API (rótulos acima dos dados).
- **Rio (cidade):** 13.782 setores censitários (IBGE 2022) com o primeiro indicador: temperatura da superfície no verão (Landsat 8–9, 2022/23–2024/25) e diferença para a mediana da cidade; renda média e mediana do responsável (Censo 2022); mapa bivariado calor × renda e painel com a temperatura por quinto de renda (Q1 − Q5 = 3,0 °C); arborização do entorno (moradores em faces com árvores: 26% no quinto mais pobre, 95% no mais rico).
- **Estado do RJ:** 92 municípios (IBGE 2022, via `geobr`), ainda sem indicadores.
- **Brasil e América Latina:** páginas e estratégia de dados definidas; camadas ainda não produzidas.
- Indicadores previstos e ainda não calculados aparecem desabilitados no seletor.

## Estrutura

```
index.html                 página inicial
rio/ estado-rj/ brasil/ america-latina/   uma página de mapa por escala
metodologia/               página pública de metodologia
css/atlas.css              estilos compartilhados
js/atlas.js                motor do mapa (lê o manifesto de cada escala)
js/i18n.js                 textos do site em inglês, português e espanhol
ferramentas/gerar_paginas.py  regenera os HTML a partir de js/i18n.js
R/00_publicar_camada.R     ponte R → site: gera GeoJSON + camada.json
R/01_importar_ibge.R       setores censitários 2022 do município do Rio
R/02_importar_municipios_rj.R  municípios do estado do RJ
R/03_temperatura_superficie_rio.R  temperatura da superfície no verão (Landsat)
R/04_renda_rio.R           renda do responsável por setor (IBGE)
R/05_calor_renda_rio.R     quintos de renda, diferença Q1−Q5, classes bivariadas
R/06_arborizacao_rio.R     arborização do entorno (IBGE) e cruzamentos
R/00_ibge_ftp.R            funções para localizar e baixar arquivos do FTP do IBGE
R/10_publicar_rio.R        junta malha + indicadores salvos e publica o Rio
dados/indicadores/<escala>/  uma tabela (.csv) + metadados (.json) por indicador
dados/processados/<escala>/    saídas publicadas (versionadas)
dados/brutos/              downloads e intermediários (fora do Git)
docs/CONTRATO_DE_DADOS.md  formato dos arquivos que o site lê
```

## Idiomas

O site está em inglês (padrão), português e espanhol, com seletor no topo. O idioma também pode ser escolhido pelo link: `?lang=pt` ou `?lang=es`. Para mudar um texto, edite `js/i18n.js` nas três línguas e rode `python3 ferramentas/gerar_paginas.py` (precisa de Node.js) para atualizar o texto em inglês gravado nos HTML.

## Como gerar as camadas

**No GitHub:** aba *Actions* → *Preparar camadas do atlas* → *Run workflow*. O workflow roda os scripts em R e faz commit das saídas em `dados/processados/`.

**No seu computador:** na raiz do repositório, `Rscript R/01_importar_ibge.R` e `Rscript R/02_importar_municipios_rj.R`.

## Visualizar localmente

Os mapas carregam arquivos via `fetch`, então abrir o HTML com duplo clique não funciona. Sirva a pasta:

```
python3 -m http.server 8000      # ou, no R: servr::httd()
```

e abra http://localhost:8000.

## Publicação

Settings → Pages → *Deploy from a branch* → `main` / `(root)`.

## Próximas etapas

1. Rodar o workflow e validar a malha do Rio e dos municípios do RJ.
3. Cobertura vegetal (copa, MapBiomas/Sentinel); população idosa e preta e parda.
5. Brasil em PMTiles; América Latina com dados harmonizados (ERA5-Land, MODIS, WorldPop, GHSL, CEPALSTAT, SALURBAL).

## Princípios metodológicos

- Não confundir temperatura superficial com temperatura do ar.
- Publicar apenas indicadores com fonte, período, unidade e método verificáveis.
- Evitar interpretações causais a partir de correlações ecológicas.
- Preservar scripts e metadados para reprodução.
