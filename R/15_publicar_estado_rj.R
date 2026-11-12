# Atlas de Desigualdade Térmica — publica a camada do estado do RJ (92 municípios)
# Executar na raiz do repositório: Rscript R/15_publicar_estado_rj.R
# Junta a malha municipal (dados/brutos/rj_municipios_2022.rds, de R/02) com os
# indicadores salvos em dados/indicadores/estado-rj/ e grava
# dados/processados/estado-rj/{unidades.geojson, camada.json}.
suppressPackageStartupMessages({ library(sf) })
source("R/00_publicar_camada.R")

arq <- "dados/brutos/rj_municipios_2022.rds"
if (!file.exists(arq)) {
  suppressPackageStartupMessages(library(geobr))
  m <- read_municipality(code_muni = "RJ", year = 2022, simplified = FALSE, showProgress = FALSE)
  m$code_muni <- as.character(m$code_muni)
  dir.create("dados/brutos", recursive = TRUE, showWarnings = FALSE)
  saveRDS(st_transform(m, 4326), arq)
}
muni <- readRDS(arq)
stopifnot(nrow(muni) == 92)
j <- carregar_indicadores(muni, escala = "estado-rj", id = "code_muni")

publicar_camada(
  j$x, escala = "estado-rj", id = "code_muni", rotulo = "name_muni",
  unidade = c(en = "Municipality", pt = "Município", es = "Municipio"),
  unidade_plural = c(en = "Municipalities", pt = "Municípios", es = "Municipios"),
  fonte_geometria = c(en = "IBGE 2022 municipal boundaries (via geobr)",
                      pt = "Malha municipal IBGE 2022 (via geobr)",
                      es = "Límites municipales IBGE 2022 (vía geobr)"),
  fonte_curta = "IBGE 2022",
  simplificar_m = 60,
  indicadores = j$indicadores
)
