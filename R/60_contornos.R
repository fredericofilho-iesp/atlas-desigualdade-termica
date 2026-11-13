# Atlas de Desigualdade Térmica — limites de nível superior para os mapas
# Executar na raiz do repositório: Rscript R/60_contornos.R
# Requer: install.packages(c("sf", "geobr", "jsonlite"))
# Grava linhas mais grossas que o site desenha por cima das unidades:
#   dados/processados/brasil/contornos.geojson          estados (união dos municípios por UF)
#   dados/processados/america-latina/contornos.geojson  países (união das unidades ADM1)
suppressPackageStartupMessages({ library(sf) })
sf_use_s2(FALSE)
gravar <- function(g, campo, arq, tol_m, crs_m) {
  geo <- st_make_valid(st_geometry(g))
  grupos <- sort(unique(as.character(g[[campo]])))
  partes <- lapply(grupos, function(k) st_union(geo[as.character(g[[campo]]) == k]))
  u <- st_sf(grupo = grupos, geometry = do.call(c, partes), crs = st_crs(g))
  u <- st_transform(st_simplify(st_transform(u, crs_m), preserveTopology = TRUE, dTolerance = tol_m), 4326)
  u <- st_cast(st_boundary(u), "MULTILINESTRING", warn = FALSE)        # só as linhas
  if (file.exists(arq)) file.remove(arq)
  st_write(u, arq, driver = "GeoJSON", quiet = TRUE, layer_options = c("COORDINATE_PRECISION=4", "RFC7946=YES"))
  message(sprintf("%s: %d grupos, %.1f MiB", arq, nrow(u), file.size(arq) / 2^20))
}
arq <- "dados/brutos/br_municipios_2022.rds"
if (!file.exists(arq)) {
  suppressPackageStartupMessages(library(geobr))
  m <- read_municipality(code_muni = "all", year = 2022, simplified = TRUE, showProgress = FALSE)
  m$code_muni <- as.character(m$code_muni)
  dir.create("dados/brutos", recursive = TRUE, showWarnings = FALSE)
  saveRDS(st_transform(m, 4326), arq)
}
gravar(readRDS(arq), "abbrev_state", "dados/processados/brasil/contornos.geojson", 1500, 5880)
if (!file.exists("dados/brutos/latam_adm1.rds")) source("R/30_unidades_latam.R", local = new.env())
gravar(readRDS("dados/brutos/latam_adm1.rds"), "iso3", "dados/processados/america-latina/contornos.geojson", 2500,
       "+proj=laea +lat_0=-10 +lon_0=-75 +datum=WGS84 +units=m")
