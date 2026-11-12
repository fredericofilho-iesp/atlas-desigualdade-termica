# Atlas de Desigualdade Térmica — malha de setores de todo o estado do RJ
# Executar na raiz do repositório: Rscript R/11_setores_estado_rj.R
# Requer: install.packages(c("sf", "dplyr"))
# Fonte: IBGE, malha DEFINITIVA dos setores censitários de 2022 (RJ_setores_CD2022.gpkg).
# Saída: dados/brutos/rj_setores_2022.rds (EPSG:4326, uma linha por setor,
#        colunas CD_SETOR, CD_MUN, AREA_M2). Não é publicada no site: serve de
#        base para calcular indicadores por setor e agregá-los por município.
suppressPackageStartupMessages({ library(sf); library(dplyr) })
options(timeout = 1800)
dir.create("dados/brutos", recursive = TRUE, showWarnings = FALSE)

url <- paste0("https://geoftp.ibge.gov.br/organizacao_do_territorio/malhas_territoriais/",
              "malhas_de_setores_censitarios__divisoes_intramunicipais/censo_2022/setores/gpkg/UF/RJ/RJ_setores_CD2022.gpkg")
dest <- "dados/brutos/RJ_setores_CD2022.gpkg"
if (!file.exists(dest) || file.size(dest) < 1e6) download.file(url, dest, mode = "wb", method = "libcurl")

malha <- st_read(dest, layer = st_layers(dest)$name[[1]], quiet = TRUE)
g <- attr(malha, "sf_column")
names(malha)[names(malha) != g] <- toupper(names(malha)[names(malha) != g])
setores <- malha |> transmute(CD_SETOR = as.character(CD_SETOR), CD_MUN = as.character(CD_MUN))

dup <- unique(setores$CD_SETOR[duplicated(setores$CD_SETOR)])
message("Linhas: ", nrow(setores), " | setores únicos: ", length(unique(setores$CD_SETOR)),
        " | repetidos (partes unidas): ", length(dup), " | municípios: ", length(unique(setores$CD_MUN)))
if (length(dup)) {
  setores <- st_make_valid(setores) |>
    group_by(CD_SETOR) |> summarise(CD_MUN = first(CD_MUN), do_union = TRUE, .groups = "drop")
}
setores <- st_make_valid(setores)
setores$AREA_M2 <- as.numeric(st_area(st_transform(setores, 5880)))  # SIRGAS 2000 / Brazil Polyconic
setores <- st_transform(setores, 4326)
stopifnot(!anyDuplicated(setores$CD_SETOR), length(unique(setores$CD_MUN)) == 92)
saveRDS(setores, "dados/brutos/rj_setores_2022.rds")
message("Salvo: dados/brutos/rj_setores_2022.rds (", nrow(setores), " setores)")
