# Atlas de Desigualdade Térmica — MODIS/Aqua MYD11A2: trimestre mais quente por pixel
# Mesmo método de R/21 (Brasil), em funções reutilizáveis:
#   modis_tiles(area, periodo)          compostos Aqua agrupados por tile que toca `area` (sf)
#   modis_processar(nome, lista, doc, pasta, lim_c)  grava <pasta>/<tile>.tif com
#        lst_quente (média dos 3 meses consecutivos mais quentes), lst_anual, mes_quente
suppressPackageStartupMessages({ library(sf); library(terra); library(rstac) })
`%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a
Sys.setenv(GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR", GDAL_HTTP_MAX_RETRY = "5",
           GDAL_HTTP_RETRY_DELAY = "3", VSI_CACHE = "TRUE")

modis_tiles <- function(area, periodo = "2022-01-01/2024-12-31") {
  caixa <- as.numeric(st_bbox(area))
  it <- stac("https://planetarycomputer.microsoft.com/api/stac/v1") |>
    stac_search(collections = "modis-11A2-061", bbox = caixa, datetime = periodo, limit = 500) |>
    post_request() |> items_fetch(progress = FALSE)
  fs <- Filter(function(f) identical(tolower(f$properties$platform %||% ""), "aqua") || startsWith(f$id, "MYD11A2"), it$features)
  tile_de <- function(f) regmatches(f$id, regexpr("h[0-9]{2}v[0-9]{2}", f$id))
  poligono <- function(f) {
    co <- f$geometry$coordinates
    if (f$geometry$type == "MultiPolygon") co <- co[[1]]
    st_polygon(list(do.call(rbind, lapply(co[[1]], function(p) as.numeric(unlist(p))))))
  }
  tiles <- split(fs, vapply(fs, tile_de, ""))
  un <- st_union(st_geometry(area))
  toca <- vapply(tiles, function(l) lengths(st_intersects(st_sfc(poligono(l[[1]]), crs = 4326), un)) > 0, TRUE)
  message("Compostos Aqua: ", length(fs), " | tiles na área: ", sum(toca), " (", paste(names(tiles)[toca], collapse = " "), ")")
  list(doc = it, tiles = tiles[toca])
}

modis_processar <- function(nome, lista, doc, pasta, lim_c = 0) {
  destino <- file.path(pasta, paste0(nome, ".tif"))
  if (file.exists(destino)) return(destino)
  if (lim_c > 0) lista <- lista[round(seq(1, length(lista), length.out = min(lim_c, length(lista))))]
  doc$features <- lista
  doc <- items_sign(doc, sign_planetary_computer())
  soma <- NULL; n <- NULL; modelo <- NULL; t0 <- Sys.time(); usados <- 0
  for (f in doc$features) {
    href <- f$assets$LST_Day_1km$href
    if (is.null(href)) next
    r <- tryCatch(rast(paste0("/vsicurl/", href)), error = function(e) NULL)
    if (is.null(r)) { message("  falhou ", f$id); next }
    v <- tryCatch(values(r, mat = FALSE), error = function(e) NULL)
    if (is.null(v)) { message("  falhou leitura ", f$id); next }
    v[!is.finite(v) | v <= 0] <- NA
    if (all(is.na(v))) next
    if (stats::median(v, na.rm = TRUE) > 1000) v <- v * 0.02   # DN → kelvin
    v <- v - 273.15
    v[v < -20 | v > 85] <- NA
    if (is.null(soma)) { modelo <- rast(r); soma <- matrix(0, length(v), 12); n <- matrix(0L, length(v), 12) }
    ini <- f$properties$start_datetime %||% f$properties$datetime
    m <- as.integer(substr(ini, 6, 7))
    ok <- !is.na(v)
    soma[ok, m] <- soma[ok, m] + v[ok]; n[ok, m] <- n[ok, m] + 1L
    usados <- usados + 1
  }
  if (is.null(soma)) return(NULL)
  mens <- soma / n; mens[n < 2] <- NA
  tri <- sapply(1:12, function(m) {
    x <- mens[, ((m - 2):m) %% 12 + 1, drop = FALSE]
    r <- rowMeans(x, na.rm = TRUE); r[rowSums(!is.na(x)) < 2] <- NA; r
  })
  t2 <- tri; t2[is.na(t2)] <- -Inf
  im <- max.col(t2, ties.method = "first")
  quente <- t2[cbind(seq_len(nrow(t2)), im)]
  quente[!is.finite(quente)] <- NA; im[is.na(quente)] <- NA
  anual <- rowMeans(mens, na.rm = TRUE); anual[rowSums(!is.na(mens)) < 9] <- NA
  out <- rast(modelo, nlyrs = 3); names(out) <- c("lst_quente", "lst_anual", "mes_quente")
  values(out) <- cbind(quente, anual, im)
  writeRaster(out, destino, overwrite = TRUE, gdal = c("COMPRESS=DEFLATE", "PREDICTOR=3"), datatype = "FLT4S")
  message(sprintf("  tile %s: %d compostos, %.0f%% dos pixels com valor (%.1f min)", nome, usados,
                  100 * mean(is.finite(quente)), as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  destino
}
