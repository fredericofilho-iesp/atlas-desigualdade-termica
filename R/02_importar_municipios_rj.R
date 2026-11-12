# Atlas de Desigualdade Térmica — malha municipal do estado do Rio de Janeiro
# Executar na raiz do repositório: Rscript R/02_importar_municipios_rj.R
# Requer: install.packages(c("sf", "jsonlite", "geobr"))
# Fonte: IBGE, malha municipal 2022, obtida pelo pacote geobr (Ipea).
# Saída: dados/processados/estado-rj/{unidades.geojson, camada.json}
# Indicadores municipais: R/14_municipios_rj.R (publicação em R/15).
suppressPackageStartupMessages({ library(sf); library(geobr) })
source("R/00_publicar_camada.R")

muni <- read_municipality(code_muni = "RJ", year = 2022, simplified = FALSE, showProgress = FALSE)
stopifnot(nrow(muni) == 92)
muni$code_muni <- as.character(muni$code_muni)
saveRDS(st_transform(muni, 4326), "dados/brutos/rj_municipios_2022.rds")

# Publica (com os indicadores já salvos, se houver).
source("R/15_publicar_estado_rj.R")
