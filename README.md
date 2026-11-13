# Atlas Interativo de Desigualdade Térmica

Plataforma acadêmica aberta para explorar exposição ao calor e desigualdades socioespaciais em quatro escalas: município do Rio de Janeiro, estado do Rio de Janeiro, Brasil e América Latina.

Site: https://fredericofilho-iesp.github.io/atlas-desigualdade-termica/

## Estado atual — v0.6

- Estrutura com uma página por escala, mapas em **MapLibre GL JS** e mapa-base OpenFreeMap, gratuito e sem chave de API (rótulos acima dos dados).
- **Rio (cidade):** 13.782 setores censitários (IBGE 2022) com o primeiro indicador: temperatura da superfície no verão (Landsat 8–9, 2022/23–2024/25) e diferença para a mediana da cidade; renda média e mediana do responsável (Censo 2022); mapa bivariado calor × renda e painel com a temperatura por quinto de renda (Q1 − Q5 = 3,0 °C); arborização do entorno (moradores em faces com árvores: 26% no quinto mais pobre, 95% no mais rico); idade (60+, 0–4) e cor ou raça, com exposição por grupo (pretos e pardos − brancos = 0,83 °C).
- **Estado do RJ:** 92 municípios, com todos os valores calculados a partir dos 41.700 setores de 2022 e ponderados pelos moradores (temperatura medida onde as pessoas moram). Temperatura da superfície cena a cena (229 cenas Landsat; nos setores da capital, r = 0,994 com o método pixel a pixel do Rio); diferença para o estado; desigualdade interna por renda (Q1 − Q5) e por cor ou raça em cada município; renda, arborização, 60+ e população preta e parda. No estado como um todo: Q1 − Q5 = 0,78 °C (IC 0,66–0,90) e pretos e pardos − brancos = 0,74 °C; na maioria dos municípios menores, porém, os mais pobres moram em áreas mais frescas.
- **Brasil:** 5.570 municípios a partir dos 458.772 setores de 2022, com os mesmos indicadores do estado. Temperatura da superfície MODIS/Aqua (1 km, 2022–2024) nos **três meses mais quentes de cada lugar** (no Norte e no Centro-Oeste, o pico é em set.–out., na seca). No país, pretos e pardos moram em lugares 0,46 °C mais quentes que brancos, mas dentro de cada estado a diferença praticamente some (−0,05 °C): a diferença nacional reflete sobretudo a geografia (Nordeste quente, Sul frio). Os painéis nacionais mostram as duas comparações.
- **América Latina:** 553 unidades subnacionais (ADM1, geoBoundaries) em 33 países, a partir de células de população de ~1 km (GHSL GHS-POP 2020) com a temperatura MODIS do trimestre mais quente de cada lugar: temperatura onde as pessoas moram, diferença para o próprio país, temperatura nas cidades (células ≥ 1.500 hab./km²) e população urbana, mais um painel país por país. A desigualdade por renda ainda não aparece nesta escala: o Índice de Riqueza Relativa da Meta foi testado e descartado (no Rio, correlação de 0,16 com a renda do Censo e sinal invertido em relação ao Landsat); ver a Metodologia. **Desigualdade por renda dentro das cidades** (R/33) com os dados do censo de cada país: Brasil (renda do responsável por setor, 2022), México (índice de marginação urbana por AGEB, CONAPO 2020, malha do INEGI) e Colômbia (pobreza multidimensional por quarteirão, DANE 2018). Validação no município do Rio: +3,3 °C (Landsat: +3,0 °C). O padrão varia de cidade para cidade: os mais pobres moram em lugares mais quentes no Rio, em Brasília, Barranquilla e Cali, e em lugares mais frescos em São Paulo, Medellín, Bogotá e Ecatepec.
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
R/11_setores_estado_rj.R   setores censitários 2022 do estado
R/12_lst_estado_rj.R       temperatura da superfície por setor, cena a cena (Landsat)
R/13_censo_estado_rj.R     renda, idade, cor ou raça e arborização por setor (IBGE)
R/14_municipios_rj.R       indicadores municipais e painéis do estado
R/15_publicar_estado_rj.R  junta malha municipal + indicadores e publica o estado
R/16_calor_extremo_rj.R    dias de calor extremo (ERA5-Land) — no ramo calor-extremo-rj, aguardando a chave do Copernicus
R/20_censo_brasil.R        Censo 2022 por setor, país inteiro
R/21_lst_modis_brasil.R    temperatura MODIS (trimestre mais quente) por setor
R/22_municipios_brasil.R   indicadores municipais e painéis nacionais (com comparação dentro das UFs)
R/23_publicar_brasil.R     publica os 5.570 municípios
R/00_modis.R               funções MODIS (trimestre mais quente por pixel), reaproveitadas
R/00_paises_latam.R        os 33 países da CELAC, com nomes em três línguas
R/30_unidades_latam.R      unidades ADM1 do geoBoundaries (com correção de nomes)
R/31_latam.R               população GHSL × temperatura MODIS; indicadores e painel por país
R/32_publicar_latam.R      publica as 553 unidades
R/33_renda_latam.R         desigualdade por renda dentro das cidades (Brasil, México, Colômbia)
ferramentas/baixar_inegi.py  baixa a malha do INEGI com um navegador (o site bloqueia downloads automáticos)
R/03_temperatura_superficie_rio.R  temperatura da superfície no verão (Landsat)
R/04_renda_rio.R           renda do responsável por setor (IBGE)
R/05_calor_renda_rio.R     quintos de renda, diferença Q1−Q5, classes bivariadas
R/06_arborizacao_rio.R     arborização do entorno (IBGE) e cruzamentos
R/07_demografia_rio.R      idade e cor ou raça (IBGE) e exposição por grupo
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

**No GitHub:** aba *Actions* → *Preparar camadas do atlas* → *Run workflow*. O workflow roda os scripts em R e faz commit das saídas em `dados/processados/` e `dados/indicadores/` (mesmo se um passo falhar, o que já foi calculado é guardado). Para o estado: `estado-rj-completo` (≈1h15, inclui a temperatura) ou `estado-rj-municipios` (minutos; reaproveita a temperatura salva). Para o Brasil: `brasil-completo` (≈1h) ou `brasil-municipios`. Para a América Latina: `latam-renda` (desigualdade por renda; ≈30 min) e `latam-completo` (≈1h20 na primeira vez; os tiles MODIS ficam em cache e as rodadas seguintes levam minutos).

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

1. Dias de calor extremo (ERA5-Land) para o estado.
2. Cobertura de copa por satélite.
3. Brasil em PMTiles (hoje GeoJSON de 8 MB).
4. América Latina: incluir mais países na desigualdade por renda (Chile, Peru, Argentina…); dias de calor extremo (ERA5-Land).

## Princípios metodológicos

- Não confundir temperatura superficial com temperatura do ar.
- Publicar apenas indicadores com fonte, período, unidade e método verificáveis.
- Evitar interpretações causais a partir de correlações ecológicas.
- Preservar scripts e metadados para reprodução.
