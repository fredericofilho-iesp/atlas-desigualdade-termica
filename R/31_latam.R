# Atlas de Desigualdade Térmica — América Latina e Caribe: calor onde as pessoas moram
# e desigualdade por riqueza relativa
# Executar na raiz do repositório: Rscript R/31_latam.R
# Requer: install.packages(c("sf", "terra", "rstac", "jsonlite"))
# Depende de: R/30_unidades_latam.R (ADM1 do geoBoundaries)
#
# Não há censo comparável entre países; por isso tudo é feito em grades harmonizadas:
#   População: GHSL GHS-POP 2020 (JRC/Comissão Europeia), células de 30″ (~1 km)
#   Temperatura: MODIS/Aqua MYD11A2, trimestre mais quente de cada pixel, 2022–2024
#                (mesmo método do Brasil; ver R/00_modis.R)
#   Riqueza: Meta Relative Wealth Index (RWI), blocos de ~2,4 km (zoom 14), via HDX.
#            O RWI ordena as áreas de mais pobres a mais ricas DENTRO de cada país
#            (não compara níveis entre países). Licença CC BY-NC 4.0. Países de renda
#            alta podem não ter RWI: ficam sem os indicadores de desigualdade.
# Cada célula populada recebe a temperatura do pixel MODIS e o RWI do bloco em que está.
#
# Indicadores por unidade (ADM1), ponderados pela população:
#   lst_pop        temperatura da superfície onde as pessoas moram
#   lst_dif_pais   lst_pop menos o valor do país
#   gap_rwi        20% mais pobres − 20% mais ricos (blocos RWI da unidade, quintos
#                  ponderados pela população; só com >= MIN_BLOCOS blocos)
# Painel: dados/processados/america-latina/paises.json (um registro por país).
#
# Variáveis de ambiente: PAISES=URY,PRY (teste); LIMITE_COMPOSTOS=n.
suppressPackageStartupMessages({ library(sf); library(terra); library(rstac); library(jsonlite) })
source("R/00_modis.R"); source("R/00_paises_latam.R"); source("R/00_publicar_camada.R")
PASTA <- "dados/brutos/modis-latam"
DIR_IND <- "dados/indicadores/america-latina-celulas"
DIR_PROC <- "dados/processados/america-latina"
MIN_BLOCOS <- 30
LIM_C <- as.integer(Sys.getenv("LIMITE_COMPOSTOS", "0"))
URL_POP <- paste0("https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_POP_GLOBE_R2023A/",
                  "GHS_POP_E2020_GLOBE_R2023A_4326_30ss/V1-0/GHS_POP_E2020_GLOBE_R2023A_4326_30ss_V1_0.zip")
terraOptions(progress = 0, memfrac = 0.6)
sf_use_s2(FALSE)
options(timeout = 3600)
set.seed(2022)
for (d in c(PASTA, DIR_IND, DIR_PROC)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

if (!file.exists("dados/brutos/latam_adm1.rds")) source("R/30_unidades_latam.R", local = new.env())
u <- readRDS("dados/brutos/latam_adm1.rds")
lim <- strsplit(Sys.getenv("PAISES", ""), ",")[[1]]
if (length(lim) && nzchar(lim[1])) u <- u[u$iso3 %in% lim, ]
u$k <- seq_len(nrow(u))
message("Unidades: ", nrow(u), " em ", length(unique(u$iso3)), " países")

# ---- MODIS: trimestre mais quente ----
t0 <- Sys.time()
mt <- modis_tiles(u)
arqs <- unlist(Map(function(n, l) modis_processar(n, l, mt$doc, PASTA, LIM_C), names(mt$tiles), mt$tiles))
unlink(file.path(PASTA, "latam.vrt"))
lst <- vrt(arqs, file.path(PASTA, "latam.vrt"))
message("MODIS: ", length(arqs), " tiles (", round(as.numeric(difftime(Sys.time(), t0, units = "mins"))), " min)")

# ---- GHS-POP 2020 ----
zipp <- "dados/brutos/ghs_pop_2020_30ss.zip"
if (!file.exists(zipp) || file.size(zipp) < 1e7) download.file(URL_POP, zipp, mode = "wb", method = "libcurl", quiet = TRUE)
tif <- grep("\\.tif$", utils::unzip(zipp, list = TRUE)$Name, value = TRUE)[1]
arq_pop <- file.path("dados/brutos", basename(tif))
if (!file.exists(arq_pop)) utils::unzip(zipp, files = tif, exdir = "dados/brutos", junkpaths = TRUE)
pop <- rast(arq_pop)
message("GHS-POP: ", tif)

# ---- RWI no HDX ----
rwi_url <- list()
hdx <- tryCatch(fromJSON(paste0("https://data.humdata.org/api/3/action/package_search?",
                                "q=%22relative%20wealth%20index%22&rows=500"), simplifyVector = FALSE)$result$results,
                error = function(e) { message("HDX indisponível: ", conditionMessage(e)); list() })
for (p in hdx) {
  if (!grepl("relative wealth", tolower(p$title %||% ""))) next
  isos <- toupper(vapply(p$groups %||% list(), function(g) g$name %||% "", ""))
  csv <- Filter(function(r) grepl("csv", tolower(r$format %||% "")) || grepl("\\.csv$", tolower(r$url %||% "")), p$resources %||% list())
  if (!length(csv)) next
  for (i in intersect(isos, PAISES_LATAM$iso3)) if (is.null(rwi_url[[i]])) rwi_url[[i]] <- csv[[1]]$url
}
message("RWI disponível para ", length(rwi_url), " de ", nrow(PAISES_LATAM), " países: ", paste(sort(names(rwi_url)), collapse = " "))
message("Sem RWI: ", paste(setdiff(PAISES_LATAM$iso3, names(rwi_url)), collapse = " "))

chave_z14 <- function(lon, lat) {
  n <- 2^14; la <- lat * pi / 180
  floor((lon + 180) / 360 * n) * n + floor((1 - log(tan(la) + 1 / cos(la)) / pi) / 2 * n)
}

# ---- país a país: células populadas ----
celulas <- list()
for (iso in unique(u$iso3)) {
  t1 <- Sys.time()
  ui <- u[u$iso3 == iso, ]
  p <- crop(pop, ext(vect(ui)) + 0.01, snap = "out")
  idx <- rasterize(vect(ui), p, field = "k")
  if (all(is.na(values(idx, mat = FALSE)))) idx <- rasterize(vect(ui), p, field = "k", touches = TRUE)
  df <- as.data.frame(c(p, idx), xy = TRUE, na.rm = TRUE)
  names(df) <- c("x", "y", "pop", "k")
  df <- df[is.finite(df$pop) & df$pop > 0, ]
  if (!nrow(df)) { message("  ", iso, ": sem população"); next }
  v <- terra::extract(lst, project(as.matrix(df[, c("x", "y")]), "EPSG:4326", crs(lst)))
  df$lst <- v[[1]]; df$mes <- v[[3]]
  df$bloco <- chave_z14(df$x, df$y)
  df$rwi <- NA_real_
  if (!is.null(rwi_url[[iso]])) {
    arq <- file.path("dados/brutos", paste0("rwi_", iso, ".csv"))
    ok <- tryCatch({ if (!file.exists(arq)) download.file(rwi_url[[iso]], arq, mode = "wb", quiet = TRUE); TRUE },
                   error = function(e) { message("  RWI ", iso, " falhou: ", conditionMessage(e)); FALSE })
    if (ok) {
      rw <- utils::read.csv(arq); names(rw) <- tolower(names(rw))
      df$rwi <- rw$rwi[match(df$bloco, chave_z14(rw$longitude, rw$latitude))]
    }
  }
  df$iso3 <- iso
  celulas[[iso]] <- df
  message(sprintf("  %s: %d células, %.1f mi pessoas, %.0f%% da pop. com temperatura, %.0f%% com RWI (%.1f min)", iso, nrow(df),
                  sum(df$pop) / 1e6, 100 * sum(df$pop[is.finite(df$lst)]) / sum(df$pop),
                  100 * sum(df$pop[is.finite(df$rwi)]) / sum(df$pop), as.numeric(difftime(Sys.time(), t1, units = "mins"))))
}
cel <- do.call(rbind, celulas); rm(celulas); gc()

# ---- blocos RWI (unidade da análise de desigualdade) ----
mp <- function(v, w) { k <- is.finite(v) & is.finite(w) & w > 0; if (!any(k)) NA_real_ else sum(v[k] * w[k]) / sum(w[k]) }
grupos_pond <- function(x, w, k) { o <- order(x); meio <- (cumsum(w[o]) - w[o] / 2) / sum(w); g <- integer(length(x)); g[o] <- pmin(k, floor(meio * k) + 1L); g }
c2 <- cel[is.finite(cel$rwi) & is.finite(cel$lst), ]
c2$lp <- c2$lst * c2$pop
bl <- stats::aggregate(cbind(pop, lp) ~ bloco + iso3 + rwi, data = c2, FUN = sum)
bl$lst <- bl$lp / bl$pop; bl$lp <- NULL
# unidade do bloco: a da maior população
c2 <- c2[order(c2$bloco, -c2$pop), ]
bl$k <- c2$k[match(bl$bloco, c2$bloco)]
utils::write.csv(transform(bl, lst = round(lst, 2), pop = round(pop), rwi = round(rwi, 3)),
                 gzfile(file.path(DIR_IND, "blocos_rwi.csv.gz")), row.names = FALSE)
message("Blocos RWI com temperatura: ", nrow(bl))

gap <- function(b) {
  if (nrow(b) < MIN_BLOCOS) return(NA_real_)
  q <- grupos_pond(b$rwi, b$pop, 5)
  mp(b$lst[q == 1], b$pop[q == 1]) - mp(b$lst[q == 5], b$pop[q == 5])
}

# ---- unidades ----
uni <- do.call(rbind, lapply(split(cel, cel$k), function(s) data.frame(
  k = s$k[1], pop = sum(s$pop), lst_pop = mp(s$lst, s$pop))))
uni <- merge(data.frame(k = u$k, id = u$id, iso3 = u$iso3), uni, by = "k", all.x = TRUE)
pais_lst <- vapply(split(cel, cel$iso3), function(s) mp(s$lst, s$pop), 0)
uni$lst_dif_pais <- uni$lst_pop - pais_lst[uni$iso3]
g_u <- vapply(split(bl, bl$k), gap, 0)
uni$gap_rwi <- unname(g_u[as.character(uni$k)])
num <- sapply(uni, is.numeric); uni[num] <- lapply(uni[num], function(v) round(v, 2))
message("Unidades com temperatura: ", sum(is.finite(uni$lst_pop)), "/", nrow(uni), " | com desigualdade RWI: ", sum(is.finite(uni$gap_rwi)))

# ---- países (painel) ----
nm <- function(iso, l) PAISES_LATAM[[l]][match(iso, PAISES_LATAM$iso3)]
mes_modal <- function(s) { k <- is.finite(s$mes); if (!any(k)) return(NA_integer_); t <- tapply(s$pop[k], s$mes[k], sum); as.integer(names(t)[which.max(t)]) }
paises <- lapply(sort(unique(cel$iso3)), function(iso) {
  s <- cel[cel$iso3 == iso, ]; b <- bl[bl$iso3 == iso, ]
  g <- gap(b); ic <- c(NA, NA)
  if (is.finite(g)) {
    bs <- replicate(200, gap(b[sample.int(nrow(b), replace = TRUE), ]))
    ic <- round(stats::quantile(bs, c(.025, .975), na.rm = TRUE, names = FALSE), 2)
  }
  list(iso3 = iso, nome = list(en = nm(iso, "en"), pt = nm(iso, "pt"), es = nm(iso, "es")),
       pop = round(sum(s$pop)), lst_pop = round(mp(s$lst, s$pop), 2), mes_quente = mes_modal(s),
       blocos_rwi = nrow(b), gap_rwi = round(g, 2), ic95 = ic)
})
gs <- vapply(paises, function(p) if (is.null(p$gap_rwi) || is.na(p$gap_rwi)) NA_real_ else p$gap_rwi, 0)
write_json(list(gerado_em = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
                paises_com_rwi = sum(is.finite(gs)), paises_mais_pobres_mais_quentes = sum(gs > 0, na.rm = TRUE),
                paises = paises),
           file.path(DIR_PROC, "paises.json"), auto_unbox = TRUE, pretty = TRUE, digits = NA, na = "null")
for (p in paises) message(sprintf("  %s  %5.1f °C  mês %s  pobres−ricos %s  (%d blocos)", p$iso3, p$lst_pop,
                                  p$mes_quente, format(p$gap_rwi), p$blocos_rwi))
message("Países com RWI: ", sum(is.finite(gs)), " | mais pobres em lugares mais quentes: ", sum(gs > 0, na.rm = TRUE))

# ---- indicadores e publicação ----
fonte <- c(en = "MODIS/Aqua MYD11A2 v6.1 (NASA); GHSL GHS-POP 2020 (JRC); geoBoundaries",
           pt = "MODIS/Aqua MYD11A2 v6.1 (NASA); GHSL GHS-POP 2020 (JRC); geoBoundaries",
           es = "MODIS/Aqua MYD11A2 v6.1 (NASA); GHSL GHS-POP 2020 (JRC); geoBoundaries")
fonte_rwi <- c(en = paste0(fonte[["en"]], "; Meta Relative Wealth Index (HDX, CC BY-NC 4.0)"),
               pt = paste0(fonte[["pt"]], "; Meta Relative Wealth Index (HDX, CC BY-NC 4.0)"),
               es = paste0(fonte[["es"]], "; Meta Relative Wealth Index (HDX, CC BY-NC 4.0)"))
per <- c(en = "Hottest three months of each place, 2022–2024 (early afternoon)", pt = "Três meses mais quentes de cada lugar, 2022–2024 (início da tarde)",
         es = "Tres meses más cálidos de cada lugar, 2022–2024 (primera hora de la tarde)")
salvar_indicadores(uni, escala = "america-latina", id = "id", indicadores = list(
  indicador("lst_pop", rotulo = c(en = "Surface temperature in the hottest season, where people live", pt = "Temperatura da superfície na época mais quente, onde as pessoas moram",
                                  es = "Temperatura de superficie en la época más cálida, donde vive la gente"),
    unidade = "°C", paleta = "calor", dimensao = "exposicao", casas_decimais = 1, ordem = 10, fonte = fonte, periodo = per,
    metodo = c(en = "MODIS 1 km daytime surface temperature over the hottest three consecutive months of each pixel, averaged over ~1 km population cells (GHS-POP 2020) and weighted by population",
               pt = "Temperatura da superfície diurna MODIS (1 km) nos três meses consecutivos mais quentes de cada pixel, média das células de população (~1 km, GHS-POP 2020) ponderada pela população",
               es = "Temperatura de superficie diurna MODIS (1 km) en los tres meses consecutivos más cálidos de cada píxel, media de las celdas de población (~1 km, GHS-POP 2020) ponderada por población")),
  indicador("lst_dif_pais", rotulo = c(en = "Surface temperature: difference from own country", pt = "Temperatura da superfície: diferença para o próprio país",
                                       es = "Temperatura de superficie: diferencia respecto a su país"),
    unidade = "°C", paleta = "divergente", dimensao = "exposicao", casas_decimais = 1, ordem = 11, quebras = c(-3, -1, 1, 3), fonte = fonte, periodo = per,
    metodo = c(en = "Unit value minus the country value (all population cells, weighted by population)",
               pt = "Valor da unidade menos o do país (todas as células de população, ponderadas pela população)",
               es = "Valor de la unidad menos el del país (todas las celdas de población, ponderadas por población)")),
  indicador("gap_rwi", rotulo = c(en = "Heat gap: poorest − richest fifth (relative wealth, within unit)", pt = "Desigualdade térmica: 20% mais pobres − 20% mais ricos (riqueza relativa, na unidade)",
                                  es = "Brecha térmica: 20% más pobre − 20% más rico (riqueza relativa, en la unidad)"),
    unidade = "°C", paleta = "divergente", dimensao = "exposicao", casas_decimais = 1, ordem = 12, quebras = c(-2, -0.5, 0.5, 2), fonte = fonte_rwi, periodo = per,
    metodo = c(en = paste0("Population-weighted surface temperature of the poorest minus the richest fifth of ~2.4 km wealth blocks (Meta RWI) in the unit; only units with at least ", MIN_BLOCOS, " blocks. Red: the poorest live in hotter places; blue: in cooler places"),
               pt = paste0("Temperatura da superfície, ponderada pela população, do quinto mais pobre menos a do quinto mais rico dos blocos de riqueza de ~2,4 km (Meta RWI) da unidade; só unidades com ao menos ", MIN_BLOCOS, " blocos. Vermelho: os mais pobres moram em lugares mais quentes; azul: em lugares menos quentes"),
               es = paste0("Temperatura de superficie, ponderada por población, del quintil más pobre menos la del más rico de los bloques de riqueza de ~2,4 km (Meta RWI) de la unidad; solo unidades con al menos ", MIN_BLOCOS, " bloques. Rojo: los más pobres viven en lugares más cálidos; azul: en lugares menos cálidos")))
))
source("R/32_publicar_latam.R")
