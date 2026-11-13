# Atlas de Desigualdade Térmica — América Latina e Caribe: calor onde as pessoas moram
# Executar na raiz do repositório: Rscript R/31_latam.R
# Requer: install.packages(c("sf", "terra", "rstac", "jsonlite"))
# Depende de: R/30_unidades_latam.R (ADM1 do geoBoundaries)
#
# Não há censo comparável entre países; por isso tudo é feito em grades harmonizadas:
#   População: GHSL GHS-POP 2020 (JRC/Comissão Europeia), células de 30″ (~1 km)
#   Temperatura: MODIS/Aqua MYD11A2, trimestre mais quente de cada pixel, 2022–2024
#                (mesmo método do Brasil; ver R/00_modis.R)
# Cada célula populada recebe a temperatura do pixel MODIS em que está.
#
# Desigualdade por renda: testamos o Meta Relative Wealth Index (blocos de ~2,4 km) e o
# descartamos. No Rio de Janeiro, onde há renda do Censo por setor, a correlação entre o
# RWI e a renda dos bairros foi quase nula (Spearman 0,16 em 180 blocos) e o índice
# apontava a Zona Norte como a área mais rica; o resultado invertia o sinal conhecido
# (mais pobres em lugares mais quentes). Ver a Metodologia do site.
#
# Indicadores por unidade (ADM1), ponderados pela população:
#   lst_pop        temperatura da superfície onde as pessoas moram
#   lst_dif_pais   lst_pop menos o valor do país
#   lst_cidades    temperatura nas células urbanas densas (>= 1.500 hab./km²)
#   pop_urbana     % da população em células com >= 300 hab./km²
# Painel: dados/processados/america-latina/paises.json (um registro por país).
#
# Variáveis de ambiente: PAISES=URY,PRY (teste); LIMITE_COMPOSTOS=n.
suppressPackageStartupMessages({ library(sf); library(terra); library(rstac); library(jsonlite) })
source("R/00_modis.R"); source("R/00_paises_latam.R"); source("R/00_publicar_camada.R")
PASTA <- "dados/brutos/modis-latam"
DIR_PROC <- "dados/processados/america-latina"
LIM_C <- as.integer(Sys.getenv("LIMITE_COMPOSTOS", "0"))
URL_POP <- paste0("https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_POP_GLOBE_R2023A/",
                  "GHS_POP_E2020_GLOBE_R2023A_4326_30ss/V1-0/GHS_POP_E2020_GLOBE_R2023A_4326_30ss_V1_0.zip")
terraOptions(progress = 0, memfrac = 0.6)
sf_use_s2(FALSE)
options(timeout = 3600)
for (d in c(PASTA, DIR_PROC)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

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
  df$iso3 <- iso
  celulas[[iso]] <- df[, c("y", "pop", "k", "lst", "mes", "iso3")]
  message(sprintf("  %s: %d células, %.1f mi pessoas, %.0f%% da pop. com temperatura (%.1f min)", iso, nrow(df),
                  sum(df$pop) / 1e6, 100 * sum(df$pop[is.finite(df$lst)]) / sum(df$pop),
                  as.numeric(difftime(Sys.time(), t1, units = "mins"))))
}
cel <- do.call(rbind, celulas); rm(celulas); gc()

# Densidade da célula de 30″ (área varia com a latitude). Limiares do GHSL:
# >= 300 hab./km² "aglomerado urbano"; >= 1.500 hab./km² "centro urbano" (cidades).
cel$dens <- cel$pop / ((111.32 / 120)^2 * cos(cel$y * pi / 180))
cel$urbano <- cel$dens >= 300
cel$denso <- cel$dens >= 1500
mp <- function(v, w) { k <- is.finite(v) & is.finite(w) & w > 0; if (!any(k)) NA_real_ else sum(v[k] * w[k]) / sum(w[k]) }
# Quantil ponderado (para a amplitude térmica entre as células habitadas de cada unidade)
qp <- function(v, w, p) { k <- is.finite(v) & is.finite(w) & w > 0; v <- v[k]; w <- w[k]; o <- order(v); v <- v[o]; w <- w[o]
  stats::approx((cumsum(w) - w / 2) / sum(w), v, xout = p, rule = 2, ties = "ordered")$y }
amp <- function(s) { k <- is.finite(s$lst) & s$pop > 0; if (sum(k) < 30) NA_real_ else qp(s$lst[k], s$pop[k], 0.9) - qp(s$lst[k], s$pop[k], 0.1) }
mes_modal <- function(s) { k <- is.finite(s$mes); if (!any(k)) return(NA_integer_); t <- tapply(s$pop[k], s$mes[k], sum); as.integer(names(t)[which.max(t)]) }
message(sprintf("População urbana (>= 300/km²): %.0f%% | em cidades (>= 1.500/km²): %.0f%%",
                100 * sum(cel$pop[cel$urbano]) / sum(cel$pop), 100 * sum(cel$pop[cel$denso]) / sum(cel$pop)))

# ---- unidades ----
uni <- do.call(rbind, lapply(split(cel, cel$k), function(s) data.frame(
  k = s$k[1], pop = sum(s$pop), lst_pop = mp(s$lst, s$pop),
  lst_cidades = if (sum(s$pop[s$denso]) >= 50000) mp(s$lst[s$denso], s$pop[s$denso]) else NA_real_,
  pop_urbana = 100 * sum(s$pop[s$urbano]) / sum(s$pop), amp_lst = amp(s))))
uni <- merge(data.frame(k = u$k, id = u$id, iso3 = u$iso3, nome = u$nome), uni, by = "k", all.x = TRUE)
pais_lst <- vapply(split(cel, cel$iso3), function(s) mp(s$lst, s$pop), 0)
uni$lst_dif_pais <- uni$lst_pop - pais_lst[uni$iso3]
num <- sapply(uni, is.numeric); uni[num] <- lapply(uni[num], function(v) round(v, 2))
message("Unidades com temperatura: ", sum(is.finite(uni$lst_pop)), "/", nrow(uni),
        " | com temperatura nas cidades: ", sum(is.finite(uni$lst_cidades)))

# ---- países (painel) ----
nm <- function(iso, l) PAISES_LATAM[[l]][match(iso, PAISES_LATAM$iso3)]
paises <- lapply(sort(unique(cel$iso3)), function(iso) {
  s <- cel[cel$iso3 == iso, ]; ui <- uni[uni$iso3 == iso & is.finite(uni$lst_pop), ]
  q <- if (nrow(ui) > 1) ui[which.max(ui$lst_pop), ] else NULL
  list(iso3 = iso, nome = list(en = nm(iso, "en"), pt = nm(iso, "pt"), es = nm(iso, "es")),
       pop = round(sum(s$pop)), lst_pop = round(mp(s$lst, s$pop), 2), mes_quente = mes_modal(s),
       lst_cidades = if (sum(s$pop[s$denso]) >= 50000) round(mp(s$lst[s$denso], s$pop[s$denso]), 2) else NA_real_,
       pop_urbana = round(100 * sum(s$pop[s$urbano]) / sum(s$pop), 1), amp_lst = round(amp(s), 2),
       unidade_mais_quente = if (is.null(q)) NULL else list(nome = q$nome, lst_pop = q$lst_pop))
})
names(paises) <- NULL
# Gini nacional da renda ou do consumo (Banco Mundial, SI.POV.GINI, a partir das pesquisas
# domiciliares de cada país): o ano mais recente desde 2015. Não há Gini subnacional
# comparável entre os países; por isso ele fica só no painel.
gini_bm <- tryCatch({
  g <- fromJSON(paste0("https://api.worldbank.org/v2/country/", paste(sort(unique(cel$iso3)), collapse = ";"),
                       "/indicator/SI.POV.GINI?format=json&per_page=2000&date=2015:2025"))[[2]]
  g <- g[is.finite(g$value), ]; g <- g[order(g$countryiso3code, -as.integer(g$date)), ]
  g[!duplicated(g$countryiso3code), c("countryiso3code", "date", "value")]
}, error = function(e) { message("Banco Mundial indisponível: ", conditionMessage(e)); NULL })
if (!is.null(gini_bm)) {
  paises <- lapply(paises, function(p) { i <- match(p$iso3, gini_bm$countryiso3code)
    if (!is.na(i)) p$gini <- list(valor = gini_bm$value[i] / 100, ano = as.integer(gini_bm$date[i])); p })
  message("Gini (Banco Mundial): ", nrow(gini_bm), " países")
}
# desigualdade por renda (R/33), quando já calculada
rj <- file.path(DIR_PROC, "renda_paises.json")
if (file.exists(rj)) { renda <- read_json(rj); paises <- lapply(paises, function(p) { p$renda <- renda[[p$iso3]]; p }) }
# calor extremo do ar (R/50), quando já calculado
cj <- file.path(DIR_PROC, "calor_ar_paises.json")
if (file.exists(cj)) { ca <- read_json(cj); paises <- lapply(paises, function(p) { p$calor_ar <- ca[[p$iso3]]; p }) }
write_json(list(gerado_em = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), paises = paises),
           file.path(DIR_PROC, "paises.json"), auto_unbox = TRUE, pretty = TRUE, digits = NA, na = "null", null = "null")
for (p in paises) message(sprintf("  %s  %5.1f °C  cidades %s  mês %s  urbano %3.0f%%  mais quente: %s", p$iso3, p$lst_pop,
                                  format(p$lst_cidades), p$mes_quente, p$pop_urbana,
                                  if (is.null(p$unidade_mais_quente)) "—" else paste0(p$unidade_mais_quente$nome, " ", p$unidade_mais_quente$lst_pop)))

# ---- indicadores e publicação ----
fonte <- c(en = "MODIS/Aqua MYD11A2 v6.1 (NASA); GHSL GHS-POP 2020 (JRC); geoBoundaries",
           pt = "MODIS/Aqua MYD11A2 v6.1 (NASA); GHSL GHS-POP 2020 (JRC); geoBoundaries",
           es = "MODIS/Aqua MYD11A2 v6.1 (NASA); GHSL GHS-POP 2020 (JRC); geoBoundaries")
per <- c(en = "Hottest three months of each place, 2022–2024 (early afternoon)", pt = "Três meses mais quentes de cada lugar, 2022–2024 (início da tarde)",
         es = "Tres meses más cálidos de cada lugar, 2022–2024 (primera hora de la tarde)")
salvar_indicadores(uni, escala = "america-latina", id = "id", indicadores = list(
  indicador("amp_lst", rotulo = c(en = "Heat inequality: hottest vs. coolest tenth of residents", pt = "Desigualdade térmica: 10% mais quentes vs. 10% mais amenos",
                                  es = "Desigualdad térmica: 10% más cálido vs. 10% más templado"),
    unidade = "°C", paleta = "calor", dimensao = "exposicao", casas_decimais = 1, ordem = 16, fonte = fonte, periodo = per,
    metodo = c(en = "Within each unit: surface temperature at the 90th percentile of residents minus the 10th percentile, over populated ~1 km cells (GHS-POP) weighted by population; units with at least 30 populated cells",
               pt = "Dentro de cada unidade: temperatura da superfície no percentil 90 dos moradores menos no percentil 10, nas células habitadas de ~1 km (GHS-POP) ponderadas pela população; unidades com pelo menos 30 células habitadas",
               es = "Dentro de cada unidad: temperatura de superficie en el percentil 90 de los residentes menos en el percentil 10, en celdas habitadas de ~1 km (GHS-POP) ponderadas por población; unidades con al menos 30 celdas habitadas")),
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
  indicador("lst_cidades", rotulo = c(en = "Surface temperature in cities, where people live", pt = "Temperatura da superfície nas cidades, onde as pessoas moram",
                                      es = "Temperatura de superficie en las ciudades, donde vive la gente"),
    unidade = "°C", paleta = "calor", dimensao = "exposicao", casas_decimais = 1, ordem = 12, fonte = fonte, periodo = per,
    metodo = c(en = "Same as the main temperature, but only in dense urban cells (at least 1,500 inhabitants per km², the GHSL urban-centre threshold); only units with at least 50,000 people in such cells",
               pt = "Igual à temperatura principal, mas só nas células urbanas densas (ao menos 1.500 habitantes por km², limiar de centro urbano do GHSL); só unidades com ao menos 50 mil pessoas nessas células",
               es = "Igual que la temperatura principal, pero solo en las celdas urbanas densas (al menos 1.500 habitantes por km², umbral de centro urbano del GHSL); solo unidades con al menos 50.000 personas en esas celdas")),
  indicador("pop_urbana", rotulo = c(en = "Population in urban areas", pt = "População em áreas urbanas", es = "Población en áreas urbanas"),
    unidade = "%", paleta = "pessoas", dimensao = "contexto", casas_decimais = 0, ordem = 60, quebras = c(40, 60, 75, 90), fonte = fonte,
    periodo = c(en = "2020", pt = "2020", es = "2020"),
    metodo = c(en = "Share of population in ~1 km cells with at least 300 inhabitants per km² (GHS-POP 2020)",
               pt = "Proporção da população em células de ~1 km com ao menos 300 habitantes por km² (GHS-POP 2020)",
               es = "Proporción de la población en celdas de ~1 km con al menos 300 habitantes por km² (GHS-POP 2020)"))
))
source("R/32_publicar_latam.R")
