# Atlas de Desigualdade Térmica — temperatura da superfície por setor, estado do RJ
# Executar na raiz do repositório: Rscript R/12_lst_estado_rj.R
# Requer: install.packages(c("sf", "terra", "rstac", "exactextractr", "jsonlite"))
# Depende de: R/11_setores_estado_rj.R
#
# Mesmos dados e máscara do município do Rio (R/03): Landsat 8/9 C2 L2 (ST_B10),
# verões 2022/23–2024/25, nuvens da cena < 70%, QA_PIXEL sem preenchimento,
# nuvem, nuvem dilatada, cirro, sombra e água.
#
# Diferença de método, para caber num computador comum com ~150 cenas e duas
# zonas UTM: em vez de compor a mediana por pixel, cada cena é resumida por
# setor (média dos pixels válidos, ponderada pela fração do pixel no setor) e
# o valor final do setor é a MEDIANA ENTRE CENAS. Uma cena só conta para um
# setor se ao menos MIN_FRAC_LIMPA da área do setor estiver sem nuvem nela.
# Cenas da mesma data que se sobrepõem são combinadas (média) antes da mediana.
# Exige MIN_CENAS datas válidas por setor.
#
# No log, os setores do município do Rio são comparados com R/03 (pixel a pixel).
#
# Variáveis de ambiente: LIMITE_CENAS=n processa só n cenas (teste rápido).
# Saídas: dados/indicadores/estado-rj-setores/lst_verao.csv
#         dados/processados/estado-rj/lst_verao_resumo.json

suppressPackageStartupMessages({
  library(sf); library(terra); library(rstac); library(exactextractr); library(jsonlite)
})

VEROES <- c("2022/23" = "2022-12-01/2023-03-31",
            "2023/24" = "2023-12-01/2024-03-31",
            "2024/25" = "2024-12-01/2025-03-31")
MAX_NUVEM_CENA <- 70
MIN_FRAC_LIMPA <- 0.5
MIN_CENAS      <- 3
MASCARA_BITS   <- as.integer(sum(2^c(0, 1, 2, 3, 4, 7)))
LIMITE         <- as.integer(Sys.getenv("LIMITE_CENAS", "0"))
STAC_URL       <- "https://planetarycomputer.microsoft.com/api/stac/v1"
SAIDA          <- "dados/indicadores/estado-rj-setores"

Sys.setenv(GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR", GDAL_HTTP_MAX_RETRY = "5",
           GDAL_HTTP_RETRY_DELAY = "3", VSI_CACHE = "TRUE")
terraOptions(progress = 0, memfrac = 0.6)
sf_use_s2(FALSE)
`%||%` <- function(a, b) if (is.null(a)) b else a

if (!file.exists("dados/brutos/rj_setores_2022.rds")) source("R/11_setores_estado_rj.R", local = new.env())
setores <- readRDS("dados/brutos/rj_setores_2022.rds")
pts <- suppressWarnings(st_coordinates(st_point_on_surface(setores)))
caixa <- st_bbox(setores)
pix_setor <- setores$AREA_M2 / 900
message("Setores do estado: ", nrow(setores))

# ---- busca ----
catalogo <- stac(STAC_URL)
cenas <- list()
for (v in names(VEROES)) {
  it <- catalogo |>
    stac_search(collections = "landsat-c2-l2", bbox = as.numeric(caixa), datetime = VEROES[[v]], limit = 250) |>
    ext_query(`eo:cloud_cover` < 70) |> post_request() |> items_fetch()
  fs <- Filter(function(f) f$properties$platform %in% c("landsat-8", "landsat-9") &&
                 f$properties$`eo:cloud_cover` < MAX_NUVEM_CENA, it$features)
  wrs <- table(vapply(fs, function(f) paste0(f$properties$`landsat:wrs_path`, "/", f$properties$`landsat:wrs_row`), ""))
  message("Verão ", v, ": ", length(fs), " cenas | órbita/ponto: ", paste(names(wrs), wrs, sep = "×", collapse = " "))
  for (f in fs) { um <- it; um$features <- list(f); cenas[[length(cenas) + 1]] <- list(doc = um, verao = v) }
}
if (LIMITE > 0) { cenas <- cenas[round(seq(1, length(cenas), length.out = min(LIMITE, length(cenas))))]
                  message("MODO TESTE: ", length(cenas), " cenas") }

# ---- cena a cena ----
cache_crs <- list()
setores_em <- function(epsg) {
  k <- as.character(epsg)
  if (is.null(cache_crs[[k]])) cache_crs[[k]] <<- st_transform(setores, epsg)
  cache_crs[[k]]
}

processar <- function(doc) {
  doc <- items_sign(doc, sign_planetary_computer())
  f <- doc$features[[1]]
  bb <- f$bbox
  dentro <- which(pts[, 1] >= bb[1] & pts[, 1] <= bb[3] & pts[, 2] >= bb[2] & pts[, 2] <= bb[4])
  if (!length(dentro)) return(NULL)
  st <- rast(paste0("/vsicurl/", f$assets$lwir11$href))
  qa <- rast(paste0("/vsicurl/", f$assets$qa_pixel$href))
  epsg <- f$properties$`proj:epsg`
  if (is.null(epsg)) epsg <- sub("^EPSG:", "", f$properties$`proj:code` %||% "")
  if (!length(epsg) || is.na(suppressWarnings(as.integer(epsg)))) epsg <- crs(st, describe = TRUE)$code
  epsg <- as.integer(epsg)
  alvo <- setores_em(epsg)[dentro, ]
  b <- st_bbox(alvo)
  janela <- ext(c(b[["xmin"]] - 300, b[["xmax"]] + 300, b[["ymin"]] - 300, b[["ymax"]] + 300))
  if (!relate(janela, ext(st), "intersects")) return(NULL)   # crop() recorta só a sobreposição
  st <- crop(st, janela, snap = "out"); qa <- crop(qa, janela, snap = "out")
  ruim <- app(qa, function(x) bitwAnd(as.integer(x), MASCARA_BITS) > 0)
  c_ <- st * 0.00341802 + 149.0 - 273.15
  c_ <- ifel(ruim | st == 0 | c_ < 0 | c_ > 80, NA, c_)
  if (global(!is.na(c_), "sum")[1, 1] == 0) return(data.frame())
  e <- exact_extract(c_, alvo, c("mean", "count"), progress = FALSE)
  frac <- e$count / pix_setor[dentro]
  ok <- is.finite(e$mean) & frac >= MIN_FRAC_LIMPA
  data.frame(i = dentro[ok], data = substr(f$properties$datetime, 1, 10), valor = e$mean[ok])
}

res <- list(); usadas <- list(); t0 <- Sys.time()
for (j in seq_along(cenas)) {
  f <- cenas[[j]]$doc$features[[1]]
  r <- tryCatch(processar(cenas[[j]]$doc), error = function(e) { message("  falhou ", f$id, ": ", conditionMessage(e)); NULL })
  n <- if (is.null(r)) 0 else nrow(r)
  message(sprintf("  [%d/%d] %s %s nuvens %2.0f%% -> %d setores limpos (%.1f min)", j, length(cenas), f$id,
                  substr(f$properties$datetime, 1, 10), f$properties$`eo:cloud_cover`, n,
                  as.numeric(difftime(Sys.time(), t0, units = "mins"))))
  if (n > 0) {
    res[[length(res) + 1]] <- r
    usadas[[length(usadas) + 1]] <- list(id = f$id, data = substr(f$properties$datetime, 1, 10),
      verao = cenas[[j]]$verao, nuvens_cena = f$properties$`eo:cloud_cover`, setores_limpos = n)
  }
  if (j %% 10 == 0) gc()
}
stopifnot(length(res) > 0)
todos <- do.call(rbind, res)

# Mesma data (cenas vizinhas da mesma passagem): média; depois mediana entre datas.
por_data <- stats::aggregate(valor ~ i + data, data = todos, FUN = mean)
med <- stats::aggregate(valor ~ i, data = por_data, FUN = stats::median)
cnt <- stats::aggregate(valor ~ i, data = por_data, FUN = length)
lst <- rep(NA_real_, nrow(setores)); n_datas <- integer(nrow(setores))
lst[med$i] <- med$valor; n_datas[cnt$i] <- cnt$valor
lst[n_datas < MIN_CENAS] <- NA

dir.create(SAIDA, recursive = TRUE, showWarnings = FALSE)
utils::write.csv(data.frame(CD_SETOR = setores$CD_SETOR, lst_verao = round(lst, 2), n_datas = n_datas),
                 file.path(SAIDA, "lst_verao.csv"), row.names = FALSE, na = "")

q <- round(stats::quantile(lst, c(0, .05, .25, .5, .75, .95, 1), na.rm = TRUE), 2)
message("Cenas usadas: ", length(usadas), " | setores com valor: ", sum(is.finite(lst)), "/", nrow(setores),
        " | datas por setor (mediana): ", stats::median(n_datas[n_datas > 0]))
message("Distribuição (°C): ", paste(names(q), q, collapse = "  "))

# Comparação com o método pixel a pixel do município do Rio (R/03).
arq_rio <- "dados/indicadores/rio/lst_verao.csv"
comp <- NULL
if (file.exists(arq_rio)) {
  rio <- utils::read.csv(arq_rio, colClasses = c(CD_SETOR = "character"))
  k <- match(rio$CD_SETOR, setores$CD_SETOR)
  a <- rio$lst_verao; b <- lst[k]; ok <- is.finite(a) & is.finite(b)
  comp <- list(setores = sum(ok), correlacao = round(stats::cor(a[ok], b[ok]), 3),
               diferenca_media = round(mean(b[ok] - a[ok]), 2), diferenca_abs_mediana = round(stats::median(abs(b[ok] - a[ok])), 2))
  message(sprintf("Rio (comparação com R/03): %d setores | r = %.3f | estado − cidade: média %.2f °C, |dif| mediana %.2f °C",
                  comp$setores, comp$correlacao, comp$diferenca_media, comp$diferenca_abs_mediana))
}

dir.create("dados/processados/estado-rj", recursive = TRUE, showWarnings = FALSE)
write_json(list(
  gerado_em = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"), veroes = as.list(VEROES),
  parametros = list(max_nuvem_cena = MAX_NUVEM_CENA, min_frac_limpa = MIN_FRAC_LIMPA, min_cenas = MIN_CENAS,
                    modo_teste = LIMITE > 0),
  cenas_usadas = length(usadas), setores = nrow(setores), setores_com_valor = sum(is.finite(lst)),
  lst_setores = as.list(q), comparacao_rio = comp, cenas = usadas
), "dados/processados/estado-rj/lst_verao_resumo.json", auto_unbox = TRUE, pretty = TRUE, digits = NA)
