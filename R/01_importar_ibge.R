# Atlas de Desigualdade Térmica — malha censitária oficial (IBGE 2022)
# Executar na raiz do repositório: Rscript R/01_importar_ibge.R
# Requer: install.packages(c("sf", "dplyr", "jsonlite"))
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
rio <- rio %>% select(any_of(c("CD_SETOR","CD_MUN","NM_MUN","AREA_KM2")))
# Em objetos sf, select() preserva a coluna geométrica automaticamente,
# independentemente do nome da coluna ativa (geom, geometry etc.).
stopifnot(inherits(rio, "sf"), !is.null(st_geometry(rio)))
rio <- st_make_valid(rio)
rio <- st_transform(rio, 4326)
# Simplificação em projeção métrica, com tolerância moderada para visualização web.
rio <- st_transform(rio, 31983)
rio <- st_simplify(rio, dTolerance=8, preserveTopology=TRUE)
rio <- st_transform(rio, 4326)
out <- "dados/processados/rio_setores_2022.geojson"
st_write(rio, out, driver="GeoJSON", delete_dsn=TRUE, quiet=TRUE)
meta <- list(
  fonte="IBGE — Malha de Setores Censitários 2022 (definitiva)",
  url=url, municipio="Rio de Janeiro", codigo_municipio="3304557",
  quantidade_setores=nrow(rio), crs="EPSG:4326",
  simplificacao_metros=8,
  aviso="Somente limites geográficos; sem indicadores térmicos ou socioeconômicos"
)
write_json(meta, "dados/processados/metadados_setores.json", auto_unbox=TRUE, pretty=TRUE)
message("Concluído: ", nrow(rio), " setores; arquivo ", out,
        " (", round(file.size(out)/1024^2,1), " MiB)")
