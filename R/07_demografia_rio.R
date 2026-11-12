# Atlas de Desigualdade Térmica — idade e cor ou raça por setor (Rio)
# ETAPA ATUAL: diagnóstico (dicionário e cabeçalhos).
suppressPackageStartupMessages({ library(jsonlite); library(readxl) })
source("R/00_publicar_camada.R")
source("R/00_ibge_ftp.R")
BASE <- "https://ftp.ibge.gov.br/Censos/Censo_Demografico_2022/Agregados_por_Setores_Censitarios/"
PASTA <- "dados/brutos/demografia"
COD_MUN <- "3304557"

dic <- baixar_ibge(sort(achar(BASE, "^dicionario.*\\.xlsx$"), decreasing = TRUE)[1], PASTA)
for (aba in excel_sheets(dic)) {
  d <- as.data.frame(read_excel(dic, sheet = aba, col_names = FALSE, .name_repair = "minimal"))
  linhas <- apply(d, 1, function(r) paste(stats::na.omit(as.character(r)), collapse = " | "))
  hit <- grep("demografia|cor ou ra|idade|anos|V01006|V0100[0-9]|^.*Básico.*V000", linhas, ignore.case = TRUE, value = TRUE)
  message("== [", aba, "] ", length(linhas), " linhas; selecionadas ", length(hit), ":\n  ", paste(utils::head(hit, 160), collapse = "\n  "))
}
for (padrao in c("demografia_BR\\.zip$", "cor_ou_raca_BR\\.zip$", "basico_BR.*\\.zip$")) {
  z <- grep(padrao, listar(paste0(BASE, "Agregados_por_Setor_csv/")), value = TRUE)[1]
  arq <- baixar_ibge(z, PASTA)
  csv <- utils::unzip(arq, list = TRUE)$Name
  csv <- csv[grepl("\\.csv$", csv, ignore.case = TRUE, useBytes = TRUE)][1]
  utils::unzip(arq, files = csv, exdir = PASTA, overwrite = TRUE)
  f <- file.path(PASTA, csv)
  message("== ", basename(z), " → ", csv, "\n  cabeçalho: ", substr(readLines(f, n = 1, warn = FALSE), 1, 3000))
  l <- system(paste0("grep -m 2 '^\"\\?", COD_MUN, "' ", shQuote(f)), intern = TRUE)
  message("  Rio:\n    ", paste(substr(l, 1, 1500), collapse = "\n    "))
}
