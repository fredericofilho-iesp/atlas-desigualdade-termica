# Atlas de Desigualdade Térmica — publica a camada do município do Rio
# Executar na raiz do repositório: Rscript R/10_publicar_rio.R
# Junta a malha de setores (dados/brutos/rio_setores_2022.rds, gerada por
# R/01_importar_ibge.R) com todos os indicadores salvos em dados/indicadores/rio/
# e grava dados/processados/rio/{unidades.geojson, camada.json}.
# Rodar de novo nunca apaga indicadores: eles vivem em dados/indicadores/.
suppressPackageStartupMessages({ library(sf) })
source("R/00_publicar_camada.R")

arq_malha <- "dados/brutos/rio_setores_2022.rds"
if (!file.exists(arq_malha)) stop("Malha não encontrada. Rode antes: Rscript R/01_importar_ibge.R")
rio <- readRDS(arq_malha)

j <- carregar_indicadores(rio, escala = "rio", id = "CD_SETOR")

publicar_camada(
  j$x, escala = "rio", id = "CD_SETOR",
  unidade = c(en = "Census tract", pt = "Setor censitário", es = "Sector censal"),
  unidade_plural = c(en = "Census tracts", pt = "Setores censitários", es = "Sectores censales"),
  fonte_geometria = c(en = "IBGE 2022 census tract boundaries (final)",
                      pt = "Malha de setores censitários IBGE 2022 (definitiva)",
                      es = "Cartografía de sectores censales IBGE 2022 (definitiva)"),
  fonte_curta = "IBGE 2022",
  simplificar_m = 8,
  indicadores = j$indicadores
)
