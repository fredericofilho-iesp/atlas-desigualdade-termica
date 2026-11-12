# Atlas de Desigualdade Térmica — temperatura da superfície no verão (Rio)
# Executar na raiz do repositório: Rscript R/03_temperatura_superficie_rio.R
# Requer: install.packages(c("sf", "terra", "rstac", "exactextractr", "jsonlite"))
#
# Fonte: Landsat 8 e 9, Collection 2 Level-2, banda de temperatura da superfície
#        (ST_B10), USGS. Acesso gratuito e sem conta pelo Microsoft Planetary
#        Computer (catálogo STAC "landsat-c2-l2").
#
# Método
#   1. Busca todas as cenas Landsat 8/9 que cobrem o município nos verões
#      (1º dez.–31 mar.) de 2022/23, 2023/24 e 2024/25, com cobertura de nuvens
#      da cena abaixo de MAX_NUVEM_CENA.
#   2. Em cada cena, converte ST_B10 para °C (K = DN × 0,00341802 + 149,0) e
#      descarta pixels marcados no QA_PIXEL como preenchimento, nuvem, nuvem
#      dilatada, cirro, sombra de nuvem ou água.
#   3. Para cada pixel de 30 m, calcula a MEDIANA de todas as observações
#      válidas e exige pelo menos MIN_OBS observações.
#   4. Para cada setor censitário, calcula a mediana ponderada pela fração do
#      pixel coberta pelo setor (exactextractr). Setores com menos de
#      MIN_PIXELS_SETOR pixels válidos (em área equivalente) ficam sem dado.
#   5. Indicador derivado: diferença entre o setor e a mediana dos setores da
#      cidade (útil para comparar padrões espaciais entre anos e cidades).
#
# Atenção: temperatura da superfície (LST) não é temperatura do ar. As imagens
# são de ~10h (horário local), em dias sem nuvens: o indicador mostra o padrão
# espacial do aquecimento das superfícies, não a temperatura que as pessoas sentem.
#
# Saídas
#   dados/indicadores/rio/lst_verao.{csv,json}, lst_dif_cidade.{csv,json}
#   dados/processados/rio/lst_verao_30m.tif  (raster da mediana, °C)
#   dados/processados/rio/lst_verao_resumo.json (cenas usadas e estatísticas)
#   e republica a camada do site (R/10_publicar_rio.R)

suppressPackageStartupMessages({
  library(sf); library(terra); library(rstac); library(exactextractr); library(jsonlite)
})
source("R/00_publicar_camada.R")

VEROES <- c("2022/23" = "2022-12-01/2023-03-31",
            "2023/24" = "2023-12-01/2024-03-31",
            "2024/25" = "2024-12-01/2025-03-31")
MAX_NUVEM_CENA   <- 70    # % da cena; a máscara por pixel faz o filtro fino
MIN_OBS          <- 3     # observações válidas por pixel
MIN_PIXELS_SETOR <- 0.5   # pixels válidos (equivalente em área) por setor
CRS_SAIDA        <- "EPSG:32723"  # UTM 23S
STAC_URL         <- "https://planetarycomputer.microsoft.com/api/stac/v1"

Sys.setenv(GDAL_DISABLE_READDIR_ON_OPEN = "EMPTY_DIR", GDAL_HTTP_MAX_RETRY = "5",
           GDAL_HTTP_RETRY_DELAY = "3", VSI_CACHE = "TRUE")
terraOptions(progress = 0)

# ---- malha ----
if (!file.exists("dados/brutos/rio_setores_2022.rds")) source("R/01_importar_ibge.R")
setores <- readRDS("dados/brutos/rio_setores_2022.rds")
setores_utm <- st_transform(setores, CRS_SAIDA)
caixa_ll <- st_bbox(st_buffer(st_transform(st_as_sfc(st_bbox(setores_utm)), 4326), 0))
area_utm <- st_as_sfc(st_bbox(setores_utm))

# Grade de saída: 30 m alinhada, cobrindo o município com folga de 300 m.
ext_saida <- ext(vect(st_buffer(area_utm, 300)))
modelo <- rast(ext_saida, resolution = 30, crs = CRS_SAIDA)

# ---- busca das cenas ----
# Bits do QA_PIXEL (Landsat C2): 0 preenchimento, 1 nuvem dilatada, 2 cirro,
# 3 nuvem, 4 sombra de nuvem, 7 água.
MASCARA_BITS <- as.integer(sum(2^c(0, 1, 2, 3, 4, 7)))

catalogo <- stac(STAC_URL)
buscar <- function(periodo) {
  catalogo |>
    stac_search(collections = "landsat-c2-l2", bbox = as.numeric(caixa_ll),
                datetime = periodo, limit = 200) |>
    ext_query(`eo:cloud_cover` < 70) |>   # mesmo valor de MAX_NUVEM_CENA
    post_request() |>
    items_fetch()
}

ler_cena <- function(f) {
  st  <- rast(paste0("/vsicurl/", f$assets$lwir11$href))
  qa  <- rast(paste0("/vsicurl/", f$assets$qa_pixel$href))
  # Janela de leitura: município + 600 m, na projeção da cena (Landsat usa UTM
  # norte com coordenadas negativas no hemisfério sul).
  bb <- st_bbox(st_transform(st_buffer(area_utm, 600), st_crs(crs(st))))
  janela <- ext(as.numeric(bb[c("xmin", "xmax", "ymin", "ymax")]))
  if (!relate(janela, ext(st), "intersects")) return(NULL)
  st <- crop(st, janela, snap = "out"); qa <- crop(qa, janela, snap = "out")
  ruim <- app(qa, function(x) bitwAnd(as.integer(x), MASCARA_BITS) > 0)
  celsius <- st * 0.00341802 + 149.0 - 273.15
  celsius <- ifel(ruim | st == 0 | celsius < 0 | celsius > 80, NA, celsius)
  out <- project(celsius, modelo, method = "bilinear")
  names(out) <- f$id
  out
}

# As URLs são assinadas por verão, logo antes da leitura (as assinaturas expiram).
camadas <- list(); usadas <- list()
for (v in names(VEROES)) {
  it <- buscar(VEROES[[v]])
  it$features <- Filter(function(f) f$properties$platform %in% c("landsat-8", "landsat-9") &&
                          f$properties$`eo:cloud_cover` < MAX_NUVEM_CENA, it$features)
  message("Verão ", v, ": ", length(it$features), " cenas Landsat 8/9 com nuvens < ", MAX_NUVEM_CENA, "%")
  if (!length(it$features)) next
  it <- items_sign(it, sign_planetary_computer())
  for (i in seq_along(it$features)) {
    f <- it$features[[i]]
    r <- tryCatch(ler_cena(f), error = function(e) { message("  falhou ", f$id, ": ", conditionMessage(e)); NULL })
    if (is.null(r)) next
    validos <- global(!is.na(r), "sum")[1, 1]
    frac <- validos / ncell(r)
    message(sprintf("  [%d/%d] %s  %s  nuvens %.0f%%  pixels válidos %.0f%%",
                    i, length(it$features), f$id, substr(f$properties$datetime, 1, 10),
                    f$properties$`eo:cloud_cover`, 100 * frac))
    if (validos == 0) next
    camadas[[length(camadas) + 1]] <- r
    usadas[[length(usadas) + 1]] <- list(
      id = f$id, data = substr(f$properties$datetime, 1, 10), verao = v,
      plataforma = f$properties$platform, nuvens_cena = f$properties$`eo:cloud_cover`,
      fracao_valida_area = round(frac, 3))
  }
}
if (!length(camadas)) stop("Nenhuma cena com pixels válidos.")
pilha <- rast(camadas)

# ---- composição por pixel ----
n_obs <- app(pilha, function(x) sum(!is.na(x)))
lst <- app(pilha, median, na.rm = TRUE)
lst <- ifel(n_obs < MIN_OBS, NA, lst)
names(lst) <- "lst_verao"
dir.create("dados/processados/rio", recursive = TRUE, showWarnings = FALSE)
writeRaster(round(lst, 2), "dados/processados/rio/lst_verao_30m.tif", overwrite = TRUE,
            datatype = "FLT4S", filetype = "COG", gdal = c("COMPRESS=DEFLATE", "PREDICTOR=3"))

# ---- agregação por setor ----
ext_med <- exact_extract(lst, setores_utm, "median", progress = FALSE)
ext_cnt <- exact_extract(lst, setores_utm, "count", progress = FALSE)
ext_obs <- exact_extract(n_obs, setores_utm, "median", progress = FALSE)
lst_setor <- ifelse(ext_cnt >= MIN_PIXELS_SETOR, ext_med, NA_real_)
mediana_cidade <- stats::median(lst_setor, na.rm = TRUE)

tabela <- data.frame(
  CD_SETOR = setores$CD_SETOR,
  lst_verao = round(lst_setor, 2),
  lst_dif_cidade = round(lst_setor - mediana_cidade, 2)
)

resumo <- list(
  gerado_em = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  veroes = as.list(VEROES),
  parametros = list(max_nuvem_cena = MAX_NUVEM_CENA, min_obs = MIN_OBS,
                    min_pixels_setor = MIN_PIXELS_SETOR, crs = CRS_SAIDA,
                    bits_mascarados_qa_pixel = c(0, 1, 2, 3, 4, 7)),
  cenas_usadas = length(usadas),
  cenas_por_verao = as.list(table(vapply(usadas, `[[`, "", "verao"))),
  setores = nrow(tabela),
  setores_com_valor = sum(is.finite(tabela$lst_verao)),
  observacoes_por_pixel_mediana_setores = stats::median(ext_obs, na.rm = TRUE),
  lst_setores = as.list(round(stats::quantile(tabela$lst_verao, c(0, .05, .25, .5, .75, .95, 1), na.rm = TRUE), 2)),
  mediana_cidade = round(mediana_cidade, 2),
  cenas = usadas
)
write_json(resumo, "dados/processados/rio/lst_verao_resumo.json", auto_unbox = TRUE, pretty = TRUE, digits = NA)
message("Cenas usadas: ", length(usadas), " | setores com valor: ", resumo$setores_com_valor,
        "/", nrow(tabela), " | mediana da cidade: ", round(mediana_cidade, 1), " °C")
message("Distribuição por setor (°C): ", paste(names(resumo$lst_setores), unlist(resumo$lst_setores), collapse = "  "))

# ---- metadados e publicação ----
periodo <- c(en = "Dec–Mar, summers 2022/23 to 2024/25 (~10 a.m., clear-sky days)",
             pt = "dez.–mar., verões 2022/23 a 2024/25 (~10h, dias sem nuvens)",
             es = "dic.–mar., veranos 2022/23 a 2024/25 (~10 h, días despejados)")
fonte <- "Landsat 8–9 C2 L2 (USGS) · Microsoft Planetary Computer"

salvar_indicadores(
  tabela, escala = "rio", id = "CD_SETOR",
  indicadores = list(
    indicador("lst_verao",
      rotulo = c(en = "Summer land surface temperature",
                 pt = "Temperatura da superfície no verão",
                 es = "Temperatura de superficie en verano"),
      unidade = "°C", paleta = "calor", dimensao = "exposicao", casas_decimais = 1,
      fonte = fonte, periodo = periodo, ordem = 10,
      metodo = c(en = "Per-pixel median of clear-sky Landsat observations; area-weighted median per tract",
                 pt = "Mediana por pixel das observações Landsat sem nuvens; mediana ponderada pela área em cada setor",
                 es = "Mediana por píxel de las observaciones Landsat despejadas; mediana ponderada por área en cada sector")),
    indicador("lst_dif_cidade",
      rotulo = c(en = "Surface temperature: difference from city median",
                 pt = "Temperatura da superfície: diferença para a mediana da cidade",
                 es = "Temperatura de superficie: diferencia respecto a la mediana de la ciudad"),
      unidade = "°C", paleta = "divergente", dimensao = "exposicao", casas_decimais = 1,
      quebras = c(-4, -1.5, 1.5, 4), fonte = fonte, periodo = periodo, ordem = 11,
      metodo = c(en = paste0("Tract value minus the median of all tracts (", round(mediana_cidade, 1), " °C)"),
                 pt = paste0("Valor do setor menos a mediana de todos os setores (", format(round(mediana_cidade, 1), decimal.mark = ","), " °C)"),
                 es = paste0("Valor del sector menos la mediana de todos los sectores (", format(round(mediana_cidade, 1), decimal.mark = ","), " °C)")))
  )
)

source("R/10_publicar_rio.R")
