# Contrato de dados entre o R e o site

O site não calcula nada: ele apenas lê, para cada escala, dois arquivos gerados em R por `publicar_camada()` (em `R/00_publicar_camada.R`):

```
dados/processados/<escala>/
├── camada.json        # manifesto: o que existe, como colorir, de onde veio
└── unidades.geojson   # geometrias + uma coluna por indicador
```

Escalas: `rio`, `estado-rj`, `brasil`, `america-latina`. Se `camada.json` não existir, a página mostra só o mapa-base e avisa que a camada não foi processada.

## camada.json

```json
{
  "versao_contrato": 2,
  "escala": "rio",
  "unidade": "Setor censitário",
  "unidade_plural": "Setores censitários",
  "fonte_geometria": "Malha de setores censitários IBGE 2022 (definitiva)",
  "fonte_curta": "IBGE 2022",
  "quantidade_unidades": 14000,
  "geometria": { "tipo": "geojson", "url": "unidades.geojson", "id": "CD_SETOR", "rotulo": "CD_SETOR" },
  "indicadores": [
    {
      "id": "lst_verao",
      "rotulo": { "en": "Summer land surface temperature", "pt": "Temperatura da superfície no verão", "es": "Temperatura de superficie en verano" },
      "unidade": "°C",
      "dimensao": "exposicao",
      "paleta": "calor",
      "fonte": "Landsat 8/9 (USGS)",
      "periodo": "dez.–mar. 2023–2025",
      "metodo": "Mediana dos pixels por setor",
      "casas_decimais": 1,
      "classificacao": "quantis",
      "quebras": [33.1, 34.6, 35.8, 37.2],
      "n_validos": 13950
    }
  ]
}
```

(Valores ilustrativos.)

- `id` de cada indicador é o nome da propriedade no GeoJSON.
- `quebras` são os limites internos das classes (n − 1 valores para n classes). São calculadas em R, então a legenda é idêntica à de qualquer mapa estático que você gerar para artigos.
- `paleta`: `calor`, `renda`, `verde` ou `pessoas`.
- `classificacao`: `"quantis"` ou `"intervalos_iguais"`; o site traduz e conta as classes.
- **Idiomas (contrato v2):** `rotulo`, `unidade`, `fonte`, `periodo`, `metodo` e, no nível da camada, `unidade`, `unidade_plural`, `fonte_geometria` e `fonte_curta` podem ser texto simples ou um objeto `{"en": "...", "pt": "...", "es": "..."}`. Em R, passe um vetor nomeado: `c(en = "...", pt = "...", es = "...")`. Se faltar o idioma do visitante, o site usa inglês e depois português.
- Valores ausentes (`null`) aparecem em cinza, como "sem dado".

## Bases grandes (Brasil, América Latina)

Quando o GeoJSON passar de ~40 MiB, use `"tipo": "pmtiles"`, com `url` absoluta para o arquivo hospedado fora do GitHub (por exemplo, Cloudflare R2) e `"camada_vetorial"` com o nome da camada dentro do PMTiles. O site carrega a biblioteca PMTiles automaticamente nesse caso.

## Como acrescentar um indicador (exemplo)

```r
source("R/00_publicar_camada.R")
rio <- readRDS("dados/brutos/rio_setores_2022.rds")      # malha sem simplificação
lst <- terra::rast("dados/brutos/lst_verao_rio.tif")      # raster já processado
rio$lst_verao <- exactextractr::exact_extract(lst, rio, "median")

publicar_camada(
  rio, escala = "rio", id = "CD_SETOR",
  unidade = "Setor censitário", unidade_plural = "Setores censitários",
  fonte_geometria = "Malha de setores censitários IBGE 2022 (definitiva)",
  fonte_curta = "IBGE 2022", simplificar_m = 8,
  indicadores = list(
    indicador("lst_verao",
              rotulo = c(en = "Summer land surface temperature",
                         pt = "Temperatura da superfície no verão",
                         es = "Temperatura de superficie en verano"),
              unidade = "°C",
              paleta = "calor", dimensao = "exposicao",
              fonte = "Landsat 8/9 (USGS)", periodo = "…", metodo = "Mediana dos pixels por setor")
  )
)
```

Cada chamada regrava a camada inteira com todos os indicadores informados, então liste sempre todos os indicadores daquela escala.
