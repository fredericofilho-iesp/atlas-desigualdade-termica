# Atlas de Desigualdade Térmica — malha censitária oficial (IBGE 2022)
# Executar na raiz do repositório: Rscript R/01_importar_ibge.R
# Requer: install.packages(c("sf", "dplyr", "jsonlite"))
# Saída: dados/brutos/rio_setores_2022.rds (malha completa) e, via
#        R/10_publicar_rio.R, dados/processados/rio/{unidades.geojson, camada.json}
# Fonte: IBGE, malha DEFINITIVA dos setores censitários de 2022.
# Atenção: apenas geometria e identificadores; não há dados de temperatura ou renda.
suppressPackageStartupMessages({library(sf);library(dplyr);library(jsonlite)})
options(timeout = 1800)
dir.create("dados/brutos", recursive=TRUE, showWarnings=FALSE)
dir.create("dados/processados", recursive=TRUE, showWarnings=FALSE)
url <- paste0(
  "https://geoftp.ibge.gov.br/organizacao_do_territorio/",
  "malhas_territoriais/malhas_de_setores_censitarios__divisoes_intramunicipais/",
  "censo_2022/setores/gpkg/UF/RJ/RJ_setores_CD2022.gpkg"
)
dest <- "dados/brutos/RJ_setores_CD2022.gpkg"
if (!file.exists(dest) || file.size(dest) < 1000000) {
  download.file(url, dest, mode="wb", method="libcurl")
}
camadas <- st_layers(dest)$name
message("Camadas: ", paste(camadas, collapse=", "))
malha <- st_read(dest, layer=camadas[[1]], quiet=TRUE)
# Preservar o nome da coluna de geometria e o atributo sf_column.
# Renomear todas as colunas quebra a referência interna da geometria em sf.
col_geom <- attr(malha, "sf_column")
col_atributos <- names(malha) != col_geom
names(malha)[col_atributos] <- toupper(names(malha)[col_atributos])
stopifnot(all(c("CD_MUN","CD_SETOR") %in% names(malha)))
# Código IBGE do município do Rio de Janeiro: 3304557.
rio <- malha %>% filter(as.character(CD_MUN) == "3304557")
stopifnot(nrow(rio) > 0)
rio <- rio %>% select(any_of(c("CD_SETOR","CD_MUN","NM_MUN")))
rio$CD_SETOR <- as.character(rio$CD_SETOR)
# A malha do IBGE pode trazer um mesmo setor em mais de uma linha (partes
# separadas do mesmo polígono). O site exige um identificador único, então
# as partes são unidas num só multipolígono por setor.
dup <- unique(rio$CD_SETOR[duplicated(rio$CD_SETOR)])
message("Linhas: ", nrow(rio), " | setores únicos: ", length(unique(rio$CD_SETOR)),
        " | setores repetidos: ", length(dup))
if (length(dup)) {
  message("Exemplos de setores repetidos: ", paste(head(dup, 5), collapse = ", "))
  rio <- st_make_valid(rio)
  rio <- rio %>%
    group_by(CD_SETOR) %>%
    summarise(CD_MUN = first(CD_MUN), NM_MUN = first(NM_MUN), do_union = TRUE, .groups = "drop")
}
stopifnot(!anyDuplicated(rio$CD_SETOR))
rio$AREA_KM2 <- round(as.numeric(st_area(st_transform(rio, 31983))) / 1e6, 4)
# Em objetos sf, select() preserva a coluna geométrica automaticamente,
# independentemente do nome da coluna ativa (geom, geometry etc.).
stopifnot(inherits(rio, "sf"), !is.null(st_geometry(rio)))
rio <- st_make_valid(rio)
rio <- st_transform(rio, 4326)
# Guarda a malha sem simplificação: é ela que deve ser usada para extrair
# valores de raster (temperatura, vegetação) nos próximos scripts.
saveRDS(rio, "dados/brutos/rio_setores_2022.rds")
# Publica a camada do site (malha + todos os indicadores já salvos).
source("R/10_publicar_rio.R")
