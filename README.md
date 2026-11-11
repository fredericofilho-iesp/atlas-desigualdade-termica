# Atlas Interativo de Desigualdade Térmica

Plataforma acadêmica aberta para explorar exposição ao calor e desigualdades socioespaciais em quatro escalas: município do Rio de Janeiro, estado do Rio de Janeiro, Brasil e América Latina.

Site: https://fredericofilho-iesp.github.io/atlas-desigualdade-termica/

## Estado atual — v0.3

- Estrutura com uma página por escala, mapas em **MapLibre GL JS** e mapa-base CARTO (rótulos acima dos dados).
- **Rio (cidade):** pronto para exibir a malha de setores censitários IBGE 2022 assim que o workflow for executado.
- **Estado do RJ:** pronto para exibir os 92 municípios (IBGE 2022, via `geobr`).
- **Brasil e América Latina:** páginas e estratégia de dados definidas; camadas ainda não produzidas.
- **Nenhum indicador térmico ou socioeconômico foi publicado ainda.** Indicadores previstos aparecem desabilitados no seletor.

## Estrutura

```
index.html                 página inicial
rio/ estado-rj/ brasil/ america-latina/   uma página de mapa por escala
metodologia/               página pública de metodologia
css/atlas.css              estilos compartilhados
js/atlas.js                motor do mapa (lê o manifesto de cada escala)
R/00_publicar_camada.R     ponte R → site: gera GeoJSON + camada.json
R/01_importar_ibge.R       setores censitários 2022 do município do Rio
R/02_importar_municipios_rj.R  municípios do estado do RJ
dados/processados/<escala>/    saídas publicadas (versionadas)
dados/brutos/              downloads e intermediários (fora do Git)
docs/CONTRATO_DE_DADOS.md  formato dos arquivos que o site lê
```

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
2. Primeiro indicador: temperatura da superfície no verão (Landsat) agregada por setor.
3. Renda domiciliar por setor (Censo 2022), após confirmar a disponibilidade no IBGE.
4. Mapa bivariado (temperatura × renda) e razão de exposição entre quintis de renda.
5. Brasil em PMTiles; América Latina com dados harmonizados (ERA5-Land, MODIS, WorldPop, GHSL, CEPALSTAT, SALURBAL).

## Princípios metodológicos

- Não confundir temperatura superficial com temperatura do ar.
- Publicar apenas indicadores com fonte, período, unidade e método verificáveis.
- Evitar interpretações causais a partir de correlações ecológicas.
- Preservar scripts e metadados para reprodução.
