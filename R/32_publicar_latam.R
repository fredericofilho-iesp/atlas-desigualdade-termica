# Atlas de Desigualdade Térmica — publica a camada da América Latina e Caribe (ADM1)
# Executar na raiz do repositório: Rscript R/32_publicar_latam.R
# Junta as unidades (dados/brutos/latam_adm1.rds, de R/30) com os indicadores de
# dados/indicadores/america-latina/ e grava dados/processados/america-latina/.
suppressPackageStartupMessages({ library(sf) })
source("R/00_publicar_camada.R")
sf_use_s2(FALSE)
if (!file.exists("dados/brutos/latam_adm1.rds")) source("R/30_unidades_latam.R", local = new.env())
u <- readRDS("dados/brutos/latam_adm1.rds")
j <- carregar_indicadores(u, escala = "america-latina", id = "id")
publicar_camada(
  j$x, escala = "america-latina", id = "id", rotulo = "rotulo",
  unidade = c(en = "Subnational unit", pt = "Unidade subnacional", es = "Unidad subnacional"),
  unidade_plural = c(en = "Subnational units", pt = "Unidades subnacionais", es = "Unidades subnacionales"),
  fonte_geometria = c(en = "geoBoundaries ADM1 (simplified)", pt = "geoBoundaries ADM1 (simplificado)", es = "geoBoundaries ADM1 (simplificado)"),
  fonte_curta = "geoBoundaries",
  simplificar_m = 1500, crs_metrico = "+proj=laea +lat_0=-10 +lon_0=-75 +datum=WGS84 +units=m", casas_coord = 4,
  indicadores = j$indicadores
)
