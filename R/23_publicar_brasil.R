# Atlas de Desigualdade Térmica — publica a camada do Brasil (5.570 municípios)
# Executar na raiz do repositório: Rscript R/23_publicar_brasil.R
# Junta a malha municipal (IBGE 2022, via geobr, versão simplificada) com os
# indicadores salvos em dados/indicadores/brasil/ e grava
# dados/processados/brasil/{unidades.geojson, camada.json}.
# A geometria é simplificada (tolerância de 600 m) para o arquivo caber no navegador.
suppressPackageStartupMessages({ library(sf) })
source("R/00_publicar_camada.R")
sf_use_s2(FALSE)

arq <- "dados/brutos/br_municipios_2022.rds"
if (!file.exists(arq)) {
  suppressPackageStartupMessages(library(geobr))
  m <- read_municipality(code_muni = "all", year = 2022, simplified = TRUE, showProgress = FALSE)
  m$code_muni <- as.character(m$code_muni)
  dir.create("dados/brutos", recursive = TRUE, showWarnings = FALSE)
  saveRDS(st_transform(m, 4326), arq)
}
muni <- readRDS(arq)
stopifnot(nrow(muni) >= 5568)
muni$nome <- paste0(muni$name_muni, " (", muni$abbrev_state, ")")
j <- carregar_indicadores(muni, escala = "brasil", id = "code_muni")

publicar_camada(
  j$x, escala = "brasil", id = "code_muni", rotulo = "nome",
  unidade = c(en = "Municipality", pt = "Município", es = "Municipio"),
  unidade_plural = c(en = "Municipalities", pt = "Municípios", es = "Municipios"),
  fonte_geometria = c(en = "IBGE 2022 municipal boundaries (via geobr, simplified)",
                      pt = "Malha municipal IBGE 2022 (via geobr, simplificada)",
                      es = "Límites municipales IBGE 2022 (vía geobr, simplificados)"),
  fonte_curta = "IBGE 2022",
  simplificar_m = 600, crs_metrico = 5880, casas_coord = 4,
  indicadores = j$indicadores
)
