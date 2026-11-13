# Atlas de Desigualdade Térmica — temperatura da superfície (MODIS) por setor, Brasil
# Executar na raiz do repositório: Rscript R/21_lst_modis_brasil.R
# Requer: install.packages(c("sf", "terra", "rstac", "exactextractr", "jsonlite"))
#
# Para o país inteiro, Landsat (30 m) exigiria ~12 mil cenas (dezenas de horas).
# Aqui se usa MODIS/Aqua MYD11A2 v6.1 (1 km, compostos de 8 dias, passagem ~13h30,
# perto da máxima diária), anos 2022–2024, via Microsoft Planetary Computer.
#
# PERÍODO MAIS QUENTE DE CADA LUGAR: no Brasil o verão (dez.–mar.) não é a época
# mais quente em toda parte — no Centro-Oeste e em boa parte do Norte e do
# Nordeste o pico é na seca (ago.–out.), e o verão chuvoso é nublado. Por isso,
# para cada pixel:
#   1. média de cada mês do ano com os compostos válidos dos 3 anos (≥ 2 compostos);
#   2. médias móveis de 3 meses consecutivos (≥ 2 meses com dado);
#   3. lst_quente = a maior dessas médias (o trimestre mais quente do lugar);
#      mes_quente = mês central desse trimestre; lst_anual = média dos 12 meses (≥ 9).
# Depois, cada setor censitário recebe a média dos pixels ponderada pela fração do
# pixel dentro do setor (exactextractr). Setores muito menores que 1 km herdam o
# valor do entorno: a escala MODIS compara municípios e grandes áreas, não ruas.
#
# Variáveis de ambiente: LIMITE_TILES=n processa só n tiles; LIMITE_COMPOSTOS=n usa
# n compostos por tile (teste rápido); UFS=RJ,ES limita tiles e extração a esses estados.
# Saídas: dados/brutos/modis/<tile>.tif (3 camadas; não versionado)
#         dados/indicadores/brasil-setores/lst_modis.csv.gz (CD_SETOR, lst_quente, lst_anual, mes_quente)
#         dados/processados/brasil/lst_modis_resumo.json

suppressPackageStartupMessages({
  library(sf); library(terra); library(rstac); library(exactextractr); library(jsonlite)
})
PERIODO  <- "2022-01-01/2024-12-31"
CAIXA_BR <- c(-74.1, -33.8, -34.7, 5.3)
STAC_URL <- "https://planetarycomputer.microsoft.com/api/stac/v1"
PASTA    <- "dados/brutos/modis"
SAIDA    <- "dados/indicadores/brasil-setores"
LIM_T    <- as.integer(Sys.getenv("LIMITE_TILES", "0"))
LIM_C    <- as.integer(Sys.getenv("LIMITE_COMPOSTOS", "0"))
UFS      <- strsplit(Sys.getenv("UFS", ""), ",")[[1]]
`%||%` <- function(a, b) if (is.null(a)) b else a
Sys.setenv(GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR", GDAL_HTTP_MAX_RETRY = "5",
           GDAL_HTTP_RETRY_DELAY = "3", VSI_CACHE = "TRUE")
terraOptions(progress = 0, memfrac = 0.6)
sf_use_s2(FALSE)
dir.create(PASTA, recursive = TRUE, showWarnings = FALSE)
dir.create(SAIDA, recursive = TRUE, showWarnings = FALSE)

# ---- busca (Aqua) e escolha dos tiles que tocam o Brasil ----
pais <- if (length(UFS) && nzchar(UFS[1])) {
  geobr::read_state(code_state = "all", year = 2020, simplified = TRUE, showProgress = FALSE) |>
    subset(abbrev_state %in% UFS) |> st_transform(4326) |> st_union()
} else geobr::read_country(year = 2020, simplified = TRUE, showProgress = FALSE) |> st_transform(4326) |> st_union()
it <- stac(STAC_URL) |>
  stac_search(collections = "modis-11A2-061", bbox = CAIXA_BR, datetime = PERIODO, limit = 500) |>
  post_request() |> items_fetch(progress = FALSE)
fs <- Filter(function(f) identical(tolower(f$properties$platform %||% ""), "aqua") || startsWith(f$id, "MYD11A2"), it$features)
tile_de <- function(f) regmatches(f$id, regexpr("h[0-9]{2}v[0-9]{2}", f$id))
poligono <- function(f) {
  co <- f$geometry$coordinates
  if (f$geometry$type == "MultiPolygon") co <- co[[1]]
  st_polygon(list(do.call(rbind, lapply(co[[1]], function(p) as.numeric(unlist(p))))))
}
tiles <- split(fs, vapply(fs, tile_de, ""))
toca <- vapply(tiles, function(l) lengths(st_intersects(st_sfc(poligono(l[[1]]), crs = 4326), pais)) > 0, TRUE)
tiles <- tiles[toca]
message("Compostos Aqua: ", length(fs), " | tiles que tocam o Brasil: ", length(tiles), " (", paste(names(tiles), collapse = " "), ")")
if (LIM_T > 0) { tiles <- tiles[seq_len(min(LIM_T, length(tiles)))]; message("MODO TESTE: ", length(tiles), " tiles") }

# ---- tile a tile: médias mensais → trimestre mais quente ----
processar_tile <- function(nome, lista) {
  destino <- file.path(PASTA, paste0(nome, ".tif"))
  if (file.exists(destino)) return(destino)
  if (LIM_C > 0) lista <- lista[round(seq(1, length(lista), length.out = min(LIM_C, length(lista))))]
  doc <- it; doc$features <- lista
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
    if (stats::median(v, na.rm = TRUE) > 1000) v <- v * 0.02   # DN → kelvin (se a escala não veio aplicada)
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
t_ini <- Sys.time()
arqs <- unlist(Map(processar_tile, names(tiles), tiles))
message("Tiles prontos: ", length(arqs), " (", round(as.numeric(difftime(Sys.time(), t_ini, units = "mins"))), " min)")
unlink(file.path(PASTA, "brasil.vrt"))
mosaico <- vrt(arqs, file.path(PASTA, "brasil.vrt"))

# ---- setores (malha definitiva do IBGE, estado por estado) ----
UF_SIGLAS <- c("RO","AC","AM","RR","PA","AP","TO","MA","PI","CE","RN","PB","PE","AL","SE","BA",
               "MG","ES","RJ","SP","PR","SC","RS","MS","MT","GO","DF")
if (length(UFS) && nzchar(UFS[1])) UF_SIGLAS <- intersect(UF_SIGLAS, UFS)
base <- paste0("https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/",
               "malhas_de_setores_censitarios__divisoes_intramunicipais/censo_2022/setores/gpkg/UF/")
options(timeout = 3600)
res <- list()
for (uf in UF_SIGLAS) {
  t0 <- Sys.time()
  dest <- file.path("dados/brutos", paste0(uf, "_setores_CD2022.gpkg"))
  if (!file.exists(dest) || file.size(dest) < 1e5)
    download.file(paste0(base, uf, "/", uf, "_setores_CD2022.gpkg"), dest, mode = "wb", method = "libcurl", quiet = TRUE)
  s <- st_read(dest, layer = st_layers(dest)$name[[1]], quiet = TRUE)
  names(s)[names(s) != attr(s, "sf_column")] <- toupper(names(s)[names(s) != attr(s, "sf_column")])
  s <- st_transform(st_make_valid(s[, "CD_SETOR"]), crs(mosaico))
  e <- exact_extract(mosaico[[1:2]], s, c("mean", "count"), progress = FALSE)
  mq <- exact_extract(mosaico[[3]], s, "majority", progress = FALSE)
  d <- data.frame(CD_SETOR = as.character(s$CD_SETOR), q = e[[1]], a = e[[2]], w = e[[3]], mes = mq)
  # setores em várias partes: média ponderada pela cobertura de pixels
  d$w[!is.finite(d$w) | d$w <= 0] <- 0
  g <- split(seq_len(nrow(d)), d$CD_SETOR)
  um <- function(i, k) { x <- d[[k]][i]; w <- d$w[i]; ok <- is.finite(x) & w > 0; if (!any(ok)) NA_real_ else sum(x[ok] * w[ok]) / sum(w[ok]) }
  res[[uf]] <- data.frame(CD_SETOR = names(g), lst_quente = round(vapply(g, um, 0, k = "q"), 2),
                          lst_anual = round(vapply(g, um, 0, k = "a"), 2),
                          mes_quente = vapply(g, function(i) d$mes[i][which.max(d$w[i])], 0))
  unlink(dest)   # libera disco: os gpkg somam alguns GB
  message(sprintf("  %s: %d setores, %.1f%% com valor (%.1f min)", uf, length(g), 100 * mean(is.finite(res[[uf]]$lst_quente)),
                  as.numeric(difftime(Sys.time(), t0, units = "mins"))))
}
out <- do.call(rbind, res)
utils::write.csv(out, gzfile(file.path(SAIDA, "lst_modis.csv.gz")), row.names = FALSE, na = "")
q <- round(stats::quantile(out$lst_quente, c(0, .05, .25, .5, .75, .95, 1), na.rm = TRUE), 2)
message("Setores: ", nrow(out), " | com valor: ", sum(is.finite(out$lst_quente)), " | trimestre mais quente (°C): ", paste(names(q), q, collapse = "  "))
message("Mês central do trimestre mais quente (setores): ", paste(names(table(out$mes_quente)), table(out$mes_quente), sep = "→", collapse = " "))

# Comparação com Landsat (verão, 30 m) nos setores do estado do RJ.
comp <- NULL
arq_rj <- "dados/indicadores/estado-rj-setores/lst_verao.csv"
if (file.exists(arq_rj)) {
  rj <- utils::read.csv(arq_rj, colClasses = c(CD_SETOR = "character"))
  k <- match(rj$CD_SETOR, out$CD_SETOR); a <- rj$lst_verao; b <- out$lst_quente[k]; ok <- is.finite(a) & is.finite(b)
  if (sum(ok) > 100) {
    comp <- list(setores = sum(ok), correlacao = round(stats::cor(a[ok], b[ok]), 3),
                 diferenca_media = round(mean(b[ok] - a[ok]), 2))
    message(sprintf("RJ (MODIS trimestre mais quente × Landsat verão): %d setores | r = %.3f | MODIS − Landsat: %.2f °C",
                    comp$setores, comp$correlacao, comp$diferenca_media))
  }
}
dir.create("dados/processados/brasil", recursive = TRUE, showWarnings = FALSE)
write_json(list(gerado_em = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), produto = "MYD11A2 v6.1 (Aqua, dia)", periodo = PERIODO,
                tiles = names(tiles), modo_teste = LIM_T > 0 || LIM_C > 0 || length(UFS) > 0 && nzchar(UFS[1]),
                setores = nrow(out), setores_com_valor = sum(is.finite(out$lst_quente)),
                lst_quente_setores = as.list(q), mes_quente = as.list(table(out$mes_quente)), comparacao_landsat_rj = comp),
           "dados/processados/brasil/lst_modis_resumo.json", auto_unbox = TRUE, pretty = TRUE, digits = NA)
