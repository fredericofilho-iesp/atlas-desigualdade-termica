# Atlas de Desigualdade Térmica — malha censitária oficial (IBGE 2022)
# Executar na raiz do repositório: Rscript R/01_importar_ibge.R
# Requer: install.packages(c("sf", "dplyr", "jsonlite"))
# Saída: dados/processados/rio/{unidades.geojson, camada.json}
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
# Guarda a malha sem simplificação: é ela que deve ser usada para extrair
# valores de raster (temperatura, vegetação) nos próximos scripts.
saveRDS(rio, "dados/brutos/rio_setores_2022.rds")
# Simplificação em projeção métrica, com tolerância moderada para visualização web.
rio <- st_transform(rio, 31983)
rio <- st_simplify(rio, dTolerance=8, preserveTopology=TRUE)
rio <- st_transform(rio, 4326)
# Publica para o site: dados/processados/rio/unidades.geojson + camada.json.
# Indicadores (temperatura, renda etc.) serão acrescentados em scripts próprios,
# que juntam colunas a `rio` e chamam publicar_camada() de novo.
source("R/00_publicar_camada.R")
publicar_camada(
  rio, escala = "rio", id = "CD_SETOR",
  unidade = "Setor censitário", unidade_plural = "Setores censitários",
  fonte_geometria = "Malha de setores censitários IBGE 2022 (definitiva)",
  fonte_curta = "IBGE 2022",
  indicadores = list()
)
