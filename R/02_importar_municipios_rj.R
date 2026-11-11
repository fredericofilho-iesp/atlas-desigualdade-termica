# Atlas de Desigualdade Térmica — malha municipal do estado do Rio de Janeiro
# Executar na raiz do repositório: Rscript R/02_importar_municipios_rj.R
# Requer: install.packages(c("sf", "jsonlite", "geobr"))
# Fonte: IBGE, malha municipal 2022, obtida pelo pacote geobr (Ipea).
# Saída: dados/processados/estado-rj/{unidades.geojson, camada.json}
# Atenção: apenas limites e nomes; ainda sem indicadores.
suppressPackageStartupMessages({ library(sf); library(geobr) })
source("R/00_publicar_camada.R")

muni <- read_municipality(code_muni = "RJ", year = 2022, simplified = FALSE, showProgress = FALSE)
stopifnot(nrow(muni) == 92)
muni$code_muni <- as.character(muni$code_muni)
saveRDS(st_transform(muni, 4326), "dados/brutos/rj_municipios_2022.rds")

publicar_camada(
  muni, escala = "estado-rj", id = "code_muni", rotulo = "name_muni",
  unidade = "Município", unidade_plural = "Municípios",
  fonte_geometria = "Malha municipal IBGE 2022 (via geobr)",
  fonte_curta = "IBGE 2022",
  simplificar_m = 60,
  indicadores = list()
)
