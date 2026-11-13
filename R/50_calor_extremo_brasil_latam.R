# Atlas de Desigualdade Térmica — dias de calor extremo (ERA5-Land): Brasil e América Latina
# Executar na raiz do repositório: Rscript R/50_calor_extremo_brasil_latam.R
# Requer: install.packages(c("sf", "terra", "jsonlite", "geobr"))
# Depende de: ferramentas/calor_grade_openmeteo.py (dados/brutos/era5land/latam_metricas.tif),
#             R/30 (unidades ADM1) e R/31 (paises.json).
#
# TEMPERATURA DO AR (2 m), não da superfície: ERA5-Land em grade de 0,1° (~11 km), lido do
# espelho público do Open-Meteo no AWS Open Data. Métricas por célula em
# ferramentas/calor_grade_openmeteo.py (2016–2025, dia civil em UTC−3).
# "Onde as pessoas moram": cada célula de população de ~1 km (GHSL GHS-POP 2020) recebe a
# célula do ERA5-Land em que está; no litoral, células contadas como mar recebem o valor das
# células de terra vizinhas. Valores de municípios (Brasil) e de unidades ADM1 (América
# Latina) são médias ponderadas pela população.
# Indicadores (nas duas escalas):
#   dias_35       dias por ano com máxima do ar ≥ 35 °C
#   tmax_quente   média das máximas diárias nos 3 meses mais quentes de cada lugar
# Variável de ambiente: ESCALAS_CALOR=brasil,america-latina (padrão: as duas).
suppressPackageStartupMessages({ library(sf); library(terra); library(jsonlite) })
source("R/00_publicar_camada.R")
source("R/00_paises_latam.R")
sf_use_s2(FALSE)
options(timeout = 3600)
ESC <- strsplit(Sys.getenv("ESCALAS_CALOR", "brasil,america-latina"), ",")[[1]]
t0 <- Sys.time(); minutos <- function() sprintf("%.1f min", as.numeric(difftime(Sys.time(), t0, units = "mins")))

# ---- métricas do ERA5-Land, com o litoral preenchido ----
m <- rast("dados/brutos/era5land/latam_metricas.tif")
names(m) <- c("dias_30", "dias_32", "dias_35", "dias_38", "txx", "tmax_quente", "mes_quente")[seq_len(nlyr(m))]
terra_ok <- !is.na(m[["tmax_quente"]])
for (k in 1:3) m <- cover(m, focal(m, 3, "mean", na.rm = TRUE, expand = FALSE))   # até ~3 células mar adentro
m[["mes_quente"]] <- round(m[["mes_quente"]])
message("ERA5-Land: ", ncol(m), "×", nrow(m), " células; terra: ", global(terra_ok, "sum", na.rm = TRUE)[[1]], " (", minutos(), ")")

# ---- população (mesmo arquivo de R/31) ----
URL_POP <- paste0("https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_POP_GLOBE_R2023A/",
                  "GHS_POP_E2020_GLOBE_R2023A_4326_30ss/V1-0/GHS_POP_E2020_GLOBE_R2023A_4326_30ss_V1_0.zip")
zipp <- "dados/brutos/ghs_pop_2020_30ss.zip"
if (!file.exists(zipp)) utils::download.file(URL_POP, zipp, mode = "wb", quiet = TRUE)
tif <- grep("\\.tif$", utils::unzip(zipp, list = TRUE)$Name, value = TRUE)[1]
arq_pop <- file.path("dados/brutos", basename(tif))
if (!file.exists(arq_pop)) utils::unzip(zipp, files = tif, exdir = "dados/brutos", junkpaths = TRUE)
pop <- rast(arq_pop)

mp <- function(v, w) { k <- is.finite(v) & is.finite(w) & w > 0; if (!any(k)) NA_real_ else sum(v[k] * w[k]) / sum(w[k]) }
# células de população de um conjunto de polígonos (campo k), com as métricas do ERA5-Land
celulas <- function(pol) {
  p <- crop(pop, ext(vect(pol)) + 0.01, snap = "out")
  idx <- rasterize(vect(pol), p, field = "k")
  df <- as.data.frame(c(p, idx), xy = TRUE, na.rm = TRUE)
  names(df) <- c("x", "y", "pop", "k")
  df <- df[is.finite(df$pop) & df$pop > 0, ]
  v <- terra::extract(m, as.matrix(df[, c("x", "y")]))
  cbind(df, v)
}
resumo <- function(df, chave) do.call(rbind, lapply(split(df, df[[chave]]), function(s) data.frame(
  k = s[[chave]][1], pop = sum(s$pop), dias_35 = mp(s$dias_35, s$pop), dias_38 = mp(s$dias_38, s$pop),
  tmax_quente = mp(s$tmax_quente, s$pop), txx = mp(s$txx, s$pop))))

fonte_ar <- function(geo) c(en = paste0("ERA5-Land (ECMWF/Copernicus C3S), hourly, via Open-Meteo (AWS Open Data); GHSL GHS-POP 2020 (JRC); ", geo["en"]),
                            pt = paste0("ERA5-Land (ECMWF/Copernicus C3S), horário, via Open-Meteo (AWS Open Data); GHSL GHS-POP 2020 (JRC); ", geo["pt"]),
                            es = paste0("ERA5-Land (ECMWF/Copernicus C3S), horario, vía Open-Meteo (AWS Open Data); GHSL GHS-POP 2020 (JRC); ", geo["es"]))
nota <- c(en = "Air temperature from a ~11 km reanalysis grid, taken at each ~1 km population cell and weighted by population. Too coarse for neighbourhood heat islands; tends to underestimate maxima in dense urban areas",
          pt = "Temperatura do ar de uma reanálise em grade de ~11 km, tomada em cada célula de população de ~1 km e ponderada pela população. Grossa demais para ilhas de calor de bairro; tende a subestimar a máxima em áreas muito urbanizadas",
          es = "Temperatura del aire de un reanálisis en grilla de ~11 km, tomada en cada celda de población de ~1 km y ponderada por población. Demasiado gruesa para islas de calor de barrio; tiende a subestimar la máxima en áreas muy urbanizadas")
inds <- function(geo, ordem) list(
  indicador("dias_35", rotulo = c(en = "Extreme heat days: maximum air temperature ≥ 35 °C", pt = "Dias de calor extremo: máxima do ar ≥ 35 °C",
                                  es = "Días de calor extremo: máxima del aire ≥ 35 °C"),
    unidade = c(en = "days/year", pt = "dias/ano", es = "días/año"), paleta = "calor", dimensao = "exposicao",
    casas_decimais = 0, ordem = ordem, quebras = c(3, 10, 30, 60), fonte = fonte_ar(geo),
    periodo = c(en = "2016–2025", pt = "2016–2025", es = "2016–2025"),
    metodo = c(en = paste0("Mean number of days per year with daily maximum 2 m air temperature ≥ 35 °C (civil day in UTC−3). ", nota["en"]),
               pt = paste0("Número médio de dias por ano com máxima diária da temperatura do ar a 2 m ≥ 35 °C (dia civil em UTC−3). ", nota["pt"]),
               es = paste0("Número medio de días por año con máxima diaria de la temperatura del aire a 2 m ≥ 35 °C (día civil en UTC−3). ", nota["es"]))),
  indicador("tmax_quente", rotulo = c(en = "Average maximum air temperature in the hottest season", pt = "Máxima média do ar na época mais quente",
                                      es = "Máxima media del aire en la época más cálida"),
    unidade = "°C", paleta = "calor", dimensao = "exposicao", casas_decimais = 1, ordem = ordem + 1, fonte = fonte_ar(geo),
    periodo = c(en = "Hottest three months of each place, 2016–2025", pt = "Três meses mais quentes de cada lugar, 2016–2025",
                es = "Tres meses más cálidos de cada lugar, 2016–2025"),
    metodo = c(en = paste0("Mean daily maximum 2 m air temperature over the three consecutive months that are hottest at each grid cell. ", nota["en"]),
               pt = paste0("Média das máximas diárias da temperatura do ar a 2 m nos três meses consecutivos mais quentes de cada célula da grade. ", nota["pt"]),
               es = paste0("Media de las máximas diarias de la temperatura del aire a 2 m en los tres meses consecutivos más cálidos de cada celda de la grilla. ", nota["es"])))
)
relato <- function(nome, r, rot) {
  o <- order(-r$dias_35)
  message(sprintf("%s: %d unidades; dias ≥ 35 °C (quantis) %s; máxima na época quente %s", nome, sum(is.finite(r$dias_35)),
                  paste(round(stats::quantile(r$dias_35, c(0, .2, .4, .6, .8, 1), na.rm = TRUE), 1), collapse = "/"),
                  paste(round(stats::quantile(r$tmax_quente, c(0, .5, 1), na.rm = TRUE), 1), collapse = "/")))
  message("  mais dias ≥ 35 °C: ", paste(sprintf("%s %.0f", rot[head(o, 8)], r$dias_35[head(o, 8)]), collapse = ", "))
}

# ---- Brasil: municípios ----
if ("brasil" %in% ESC) {
  arq <- "dados/brutos/br_municipios_2022.rds"
  if (!file.exists(arq)) {
    suppressPackageStartupMessages(library(geobr))
    mu <- read_municipality(code_muni = "all", year = 2022, simplified = TRUE, showProgress = FALSE)
    mu$code_muni <- as.character(mu$code_muni)
    dir.create("dados/brutos", recursive = TRUE, showWarnings = FALSE)
    saveRDS(st_transform(mu, 4326), arq)
  }
  mu <- readRDS(arq); mu$k <- seq_len(nrow(mu))
  df <- celulas(mu)
  r <- resumo(df, "k"); r$code_muni <- mu$code_muni[r$k]
  r <- merge(data.frame(code_muni = mu$code_muni), r, by = "code_muni", all.x = TRUE)
  message(sprintf("Brasil: %.1f mi pessoas em %d células; %d municípios sem célula de população (%s)",
                  sum(df$pop) / 1e6, nrow(df), sum(!is.finite(r$dias_35)), minutos()))
  relato("Brasil", r, paste0(mu$name_muni, " (", mu$abbrev_state, ")")[match(r$code_muni, mu$code_muni)])
  message(sprintf("Brasil (ponderado pela população): %.1f dias ≥ 35 °C por ano; máxima na época quente %.1f °C",
                  mp(df$dias_35, df$pop), mp(df$tmax_quente, df$pop)))
  rio <- r[r$code_muni == "3304557", ]
  message(sprintf("Validação — município do Rio: %.1f dias ≥ 35 °C (R/16, setores: ver estado-rj/dias_35)", rio$dias_35))
  salvar_indicadores(r, escala = "brasil", id = "code_muni",
                     indicadores = inds(c(en = "IBGE municipal boundaries 2022", pt = "malha municipal IBGE 2022", es = "malla municipal IBGE 2022"), 14))
  source("R/23_publicar_brasil.R", local = new.env())
}

# ---- América Latina: unidades ADM1 e países ----
if ("america-latina" %in% ESC) {
  if (!file.exists("dados/brutos/latam_adm1.rds")) source("R/30_unidades_latam.R", local = new.env())
  u <- readRDS("dados/brutos/latam_adm1.rds"); u$k <- seq_len(nrow(u))
  todas <- list(); paises <- list()
  for (iso in unique(u$iso3)) {
    df <- celulas(u[u$iso3 == iso, ])
    if (!nrow(df)) next
    todas[[iso]] <- resumo(df, "k")
    paises[[iso]] <- list(dias_35 = round(mp(df$dias_35, df$pop), 1), tmax_quente = round(mp(df$tmax_quente, df$pop), 1),
                          txx = round(mp(df$txx, df$pop), 1))
  }
  r <- do.call(rbind, todas); r$id <- u$id[r$k]
  r <- merge(data.frame(id = u$id), r, by = "id", all.x = TRUE)
  relato("América Latina", r, u$rotulo[match(r$id, u$id)])
  for (iso in names(paises)) message(sprintf("  %s  %5.1f dias ≥ 35 °C  máxima na época quente %.1f °C", iso, paises[[iso]]$dias_35, paises[[iso]]$tmax_quente))
  write_json(paises, "dados/processados/america-latina/calor_ar_paises.json", auto_unbox = TRUE, pretty = TRUE, digits = NA, na = "null")
  pj <- "dados/processados/america-latina/paises.json"
  if (file.exists(pj)) {
    P <- read_json(pj)
    P$paises <- lapply(P$paises, function(p) { p$calor_ar <- paises[[p$iso3]]; p })
    write_json(P, pj, auto_unbox = TRUE, pretty = TRUE, digits = NA, na = "null", null = "null")
  }
  salvar_indicadores(r, escala = "america-latina", id = "id",
                     indicadores = inds(c(en = "geoBoundaries", pt = "geoBoundaries", es = "geoBoundaries"), 14))
  source("R/32_publicar_latam.R", local = new.env())
}
message("Concluído (", minutos(), ")")
