# Atlas de Desigualdade Térmica — dias de calor extremo (ERA5-Land), estado do RJ
# Executar na raiz do repositório: Rscript R/16_calor_extremo_rj.R
# Requer: install.packages(c("sf", "terra", "jsonlite"))
# Depende de: ferramentas/baixar_era5land.py (máximas diárias em dados/brutos/era5land/rj/),
#             R/11 (setores) e R/13 (moradores por setor).
#
# TEMPERATURA DO AR, não da superfície: ERA5-Land (ECMWF/Copernicus), reanálise
# em grade de 0,1° (~11 km), temperatura máxima diária a 2 m, dia civil em UTC−3.
# Cada setor censitário recebe a célula da grade em que está (ou a célula de terra
# mais próxima, no litoral); o valor municipal é a média dos setores ponderada
# pelos moradores — o calor "onde as pessoas moram", como nos demais indicadores.
#
# Indicadores (período ANO_INI–ANO_FIM, anos completos):
#   dias_35     dias por ano com máxima ≥ 35 °C (média dos anos)
#   tmax_verao  média das máximas diárias em dez.–mar. (verões completos do período)
# Limiares de 30–38 °C ficam registrados na tabela por célula, para comparação.
# A grade de ~11 km não vê ilhas de calor de bairro e tende a subestimar a máxima
# em áreas muito urbanizadas: serve para comparar municípios, não ruas.
#
# Saídas: dados/indicadores/estado-rj-setores/era5land_celulas.csv
#         dados/indicadores/estado-rj/{dias_35, tmax_verao}.{csv,json}

suppressPackageStartupMessages({ library(sf); library(terra); library(jsonlite) })
source("R/00_publicar_camada.R")
ANO_INI <- 2016; ANO_FIM <- 2025
LIMIARES <- c(30, 32, 34, 35, 36, 38)
PASTA <- "dados/brutos/era5land/rj"
DIR <- "dados/indicadores/estado-rj-setores"
sf_use_s2(FALSE)

# ---- grade diária ----
arqs <- sort(list.files(PASTA, "\\.nc$", full.names = TRUE))
if (!length(arqs)) stop("Nenhum arquivo em ", PASTA, ": rode antes ferramentas/baixar_era5land.py")
r <- rast(arqs)
datas <- as.Date(time(r))
if (anyNA(datas)) stop("Arquivos sem datas reconhecíveis: ", paste(basename(arqs), collapse = ", "))
o <- order(datas); o <- o[!duplicated(datas[o])]
r <- r[[o]]; datas <- datas[o]
ok_per <- format(datas, "%Y") >= ANO_INI & format(datas, "%Y") <= ANO_FIM
r <- r[[which(ok_per)]]; datas <- datas[ok_per]
anos <- as.integer(format(datas, "%Y")); meses <- as.integer(format(datas, "%m"))
falta <- setdiff(ANO_INI:ANO_FIM, unique(anos[table(anos)[as.character(anos)] >= 365]))
if (length(falta)) stop("Anos incompletos ou ausentes: ", paste(falta, collapse = ", "))
message("ERA5-Land: ", nlyr(r), " dias (", min(datas), " a ", max(datas), ") | grade ",
        ncol(r), "×", nrow(r), " | resolução ", paste(round(res(r), 3), collapse = "×"))

# ---- setores → células ----
setores <- readRDS("dados/brutos/rj_setores_2022.rds")
pts <- suppressWarnings(st_coordinates(st_transform(st_point_on_surface(setores), 4326)))
censo <- utils::read.csv(file.path(DIR, "censo.csv"), colClasses = c(CD_SETOR = "character", CD_MUN = "character"))
meio <- r[[which.min(abs(datas - as.Date(paste0(ANO_FIM, "-01-15"))))]]
valida <- which(!is.na(values(meio, mat = FALSE)))
cel <- cellFromXY(r, pts)
ruim <- is.na(cel) | !(cel %in% valida)
if (any(ruim)) {
  xy_ok <- xyFromCell(r, valida)
  k <- cos(mean(pts[, 2]) * pi / 180)
  for (i in which(ruim)) {
    d2 <- ((xy_ok[, 1] - pts[i, 1]) * k)^2 + (xy_ok[, 2] - pts[i, 2])^2
    cel[i] <- valida[which.min(d2)]
  }
}
message("Setores: ", nrow(setores), " | células usadas: ", length(unique(cel)),
        " | setores levados à célula de terra mais próxima: ", sum(ruim))

# ---- métricas por célula ----
uc <- sort(unique(cel))
M <- as.matrix(terra::extract(r, uc))           # células × dias
if (stats::median(M, na.rm = TRUE) > 200) M <- M - 273.15   # kelvin → °C
n_anos <- ANO_FIM - ANO_INI + 1
dias_ano <- function(lim) {
  por_ano <- sapply(ANO_INI:ANO_FIM, function(a) rowSums(M[, anos == a, drop = FALSE] >= lim, na.rm = TRUE))
  rowMeans(por_ano)
}
verao <- (meses == 12 & anos < ANO_FIM) | (meses <= 3 & anos > ANO_INI)
cels <- data.frame(celula = uc, lon = round(xyFromCell(r, uc)[, 1], 3), lat = round(xyFromCell(r, uc)[, 2], 3),
                   tmax_verao = round(rowMeans(M[, verao, drop = FALSE], na.rm = TRUE), 2),
                   txx = round(rowMeans(sapply(ANO_INI:ANO_FIM, function(a) apply(M[, anos == a, drop = FALSE], 1, max, na.rm = TRUE))), 2))
for (l in LIMIARES) cels[[paste0("dias_", l)]] <- round(dias_ano(l), 2)
dir.create(DIR, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(cels, file.path(DIR, "era5land_celulas.csv"), row.names = FALSE)

# ---- municípios (ponderado por moradores) ----
s <- data.frame(CD_SETOR = setores$CD_SETOR, celula = cel)
s$moradores <- censo$moradores[match(s$CD_SETOR, censo$CD_SETOR)]
s$CD_MUN <- substr(s$CD_SETOR, 1, 7)
s <- cbind(s, cels[match(s$celula, cels$celula), setdiff(names(cels), c("celula", "lon", "lat"))])
mp <- function(v, w) { w[!is.finite(w)] <- 0; if (sum(w) == 0) w[] <- 1; sum(v * w) / sum(w) }
col <- c("tmax_verao", "txx", paste0("dias_", LIMIARES))
mun <- do.call(rbind, lapply(split(s, s$CD_MUN), function(x)
  data.frame(code_muni = x$CD_MUN[1], t(sapply(col, function(k) mp(x[[k]], x$moradores))))))
stopifnot(nrow(mun) == 92)
est <- sapply(col, function(k) mp(s[[k]], s$moradores))
message("Estado (ponderado por moradores): ", paste(sprintf("%s %.1f", names(est), est), collapse = " | "))
for (k in c("dias_35", "tmax_verao")) {
  oo <- order(-mun[[k]])
  message(k, " — maiores: ", paste(sprintf("%s %.1f", mun$code_muni[head(oo, 6)], mun[[k]][head(oo, 6)]), collapse = ", "),
          " | menores: ", paste(sprintf("%s %.1f", mun$code_muni[tail(oo, 4)], mun[[k]][tail(oo, 4)]), collapse = ", "))
  message(k, " — quantis municipais: ", paste(round(stats::quantile(mun[[k]], c(0, .2, .4, .6, .8, 1)), 1), collapse = " / "))
}
lst <- file.path("dados/indicadores/estado-rj", "lst_pop.csv")
if (file.exists(lst)) {
  l <- utils::read.csv(lst, colClasses = c(code_muni = "character"))
  v <- l$lst_pop[match(mun$code_muni, l$code_muni)]
  message(sprintf("Correlação entre municípios com a temperatura da superfície: tmax_verao r = %.2f | dias_35 r = %.2f",
                  stats::cor(v, mun$tmax_verao, use = "complete"), stats::cor(v, mun$dias_35, use = "complete")))
}

fonte <- c(en = "ERA5-Land (ECMWF/Copernicus C3S), daily statistics; IBGE 2022 Census",
           pt = "ERA5-Land (ECMWF/Copernicus C3S), estatísticas diárias; IBGE, Censo 2022",
           es = "ERA5-Land (ECMWF/Copernicus C3S), estadísticas diarias; IBGE, Censo 2022")
per <- c(en = paste0(ANO_INI, "–", ANO_FIM), pt = paste0(ANO_INI, "–", ANO_FIM), es = paste0(ANO_INI, "–", ANO_FIM))
per_v <- c(en = paste0("Dec–Mar, summers ", ANO_INI, "/", substr(ANO_INI + 1, 3, 4), " to ", ANO_FIM - 1, "/", substr(ANO_FIM, 3, 4)),
           pt = paste0("dez.–mar., verões ", ANO_INI, "/", substr(ANO_INI + 1, 3, 4), " a ", ANO_FIM - 1, "/", substr(ANO_FIM, 3, 4)),
           es = paste0("dic.–mar., veranos ", ANO_INI, "/", substr(ANO_INI + 1, 3, 4), " a ", ANO_FIM - 1, "/", substr(ANO_FIM, 3, 4)))
nota <- c(en = "Air temperature from a ~11 km reanalysis grid; each census tract takes its grid cell and municipal values are weighted by residents. Too coarse for neighbourhood heat islands, and likely to underestimate maxima in dense urban areas",
          pt = "Temperatura do ar de uma reanálise em grade de ~11 km; cada setor censitário recebe a sua célula e o valor municipal é ponderado pelos moradores. Grossa demais para ilhas de calor de bairro e tende a subestimar a máxima em áreas muito urbanizadas",
          es = "Temperatura del aire de un reanálisis en grilla de ~11 km; cada sector censal toma su celda y el valor municipal se pondera por residentes. Demasiado gruesa para islas de calor de barrio y tiende a subestimar la máxima en áreas muy urbanizadas")
salvar_indicadores(mun, escala = "estado-rj", id = "code_muni", indicadores = list(
  indicador("dias_35", rotulo = c(en = "Extreme heat days: maximum air temperature ≥ 35 °C", pt = "Dias de calor extremo: máxima do ar ≥ 35 °C",
                                  es = "Días de calor extremo: máxima del aire ≥ 35 °C"),
    unidade = c(en = "days/year", pt = "dias/ano", es = "días/año"), paleta = "calor", dimensao = "exposicao",
    casas_decimais = 0, ordem = 14, fonte = fonte, periodo = per,
    metodo = c(en = paste0("Mean number of days per year with daily maximum 2 m air temperature ≥ 35 °C. ", nota["en"]),
               pt = paste0("Número médio de dias por ano com máxima diária da temperatura do ar a 2 m ≥ 35 °C. ", nota["pt"]),
               es = paste0("Número medio de días por año con máxima diaria de la temperatura del aire a 2 m ≥ 35 °C. ", nota["es"]))),
  indicador("tmax_verao", rotulo = c(en = "Average summer maximum air temperature", pt = "Máxima média do ar no verão",
                                     es = "Máxima media del aire en verano"),
    unidade = "°C", paleta = "calor", dimensao = "exposicao", casas_decimais = 1, ordem = 15, fonte = fonte, periodo = per_v,
    metodo = c(en = paste0("Mean of daily maximum 2 m air temperature, December to March. ", nota["en"]),
               pt = paste0("Média das máximas diárias da temperatura do ar a 2 m, de dezembro a março. ", nota["pt"]),
               es = paste0("Media de las máximas diarias de la temperatura del aire a 2 m, de diciembre a marzo. ", nota["es"])))
))
write_json(list(gerado_em = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), periodo = c(ANO_INI, ANO_FIM),
                dias = nlyr(r), celulas = length(uc), setores_realocados = sum(ruim), estado = as.list(round(est, 2))),
           "dados/processados/estado-rj/era5land_resumo.json", auto_unbox = TRUE, pretty = TRUE, digits = NA)

source("R/15_publicar_estado_rj.R")
