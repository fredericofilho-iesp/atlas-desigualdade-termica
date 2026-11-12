# Atlas de Desigualdade Térmica — unidades subnacionais da América Latina e Caribe
# Executar na raiz do repositório: Rscript R/30_unidades_latam.R
# Requer: install.packages(c("sf", "jsonlite"))
# Fonte: geoBoundaries (William & Mary geoLab), primeiro nível administrativo (ADM1:
# estados, províncias, departamentos, regiões), versão simplificada, licenças abertas.
# Saída: dados/brutos/latam_adm1.rds (EPSG:4326; colunas id, nome, iso3, pais_*).
# Variável de ambiente: PAISES=URY,PRY limita aos países dados (teste).
suppressPackageStartupMessages({ library(sf); library(jsonlite) })
source("R/00_paises_latam.R")
sf_use_s2(FALSE)
options(timeout = 600)

lim <- strsplit(Sys.getenv("PAISES", ""), ",")[[1]]
isos <- if (length(lim) && nzchar(lim[1])) intersect(PAISES_LATAM$iso3, lim) else PAISES_LATAM$iso3

baixar_adm1 <- function(iso) {
  for (tipo in c("gbOpen", "gbHumanitarian", "gbAuthoritative")) {
    meta <- tryCatch(fromJSON(paste0("https://www.geoboundaries.org/api/current/", tipo, "/", iso, "/ADM1/")),
                     error = function(e) NULL)
    if (is.null(meta) || is.null(meta$simplifiedGeometryGeoJSON)) next
    g <- tryCatch(st_read(meta$simplifiedGeometryGeoJSON, quiet = TRUE), error = function(e) NULL)
    if (is.null(g) || !nrow(g)) next
    g <- st_make_valid(st_transform(g, 4326))
    nome <- if ("shapeName" %in% names(g)) as.character(g$shapeName) else paste0(iso, "-", seq_len(nrow(g)))
    message(sprintf("  %s: %d unidades (%s, %s)", iso, nrow(g), tipo, meta$boundaryYearRepresented %||% "?"))
    return(st_sf(id = paste0(iso, "-", sprintf("%03d", seq_len(nrow(g)))), nome = nome, iso3 = iso,
                 fonte = tipo, geometry = st_geometry(g)))
  }
  message("  ", iso, ": sem ADM1 no geoBoundaries — usa o país inteiro")
  NULL
}
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

lista <- lapply(isos, baixar_adm1)
falta <- isos[vapply(lista, is.null, TRUE)]
u <- do.call(rbind, Filter(Negate(is.null), lista))
if (length(falta)) {
  # Países sem ADM1 (raro): a unidade é o próprio país, pela união do geoBoundaries ADM0.
  for (iso in falta) {
    meta <- fromJSON(paste0("https://www.geoboundaries.org/api/current/gbOpen/", iso, "/ADM0/"))
    g <- st_make_valid(st_transform(st_read(meta$simplifiedGeometryGeoJSON, quiet = TRUE), 4326))
    u <- rbind(u, st_sf(id = paste0(iso, "-000"), nome = PAISES_LATAM$es[PAISES_LATAM$iso3 == iso], iso3 = iso,
                        fonte = "gbOpen ADM0", geometry = st_union(st_geometry(g))))
  }
}
# Recorta reivindicações antárticas e ilhas muito ao sul (ex.: Tierra del Fuego no geoBoundaries).
u <- suppressWarnings(st_crop(u, st_bbox(c(xmin = -120, ymin = -60, xmax = -25, ymax = 35), crs = st_crs(4326))))
u <- u[!st_is_empty(u), ]
u <- st_cast(u, "MULTIPOLYGON", warn = FALSE)
u$rotulo <- paste0(u$nome, " (", u$iso3, ")")
dir.create("dados/brutos", recursive = TRUE, showWarnings = FALSE)
saveRDS(u, "dados/brutos/latam_adm1.rds")
message("Unidades: ", nrow(u), " em ", length(unique(u$iso3)), " países")
