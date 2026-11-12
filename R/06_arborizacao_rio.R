# Atlas de Desigualdade Térmica — arborização do entorno por setor (Rio)
# Executar na raiz do repositório: Rscript R/06_arborizacao_rio.R
#
# Fonte: IBGE, Censo 2022, "Agregados por Setores Censitários — Características
#        urbanísticas do entorno dos domicílios".
#
# ETAPA ATUAL: diagnóstico. Lista os arquivos, mostra as variáveis do
# dicionário ligadas a arborização e o cabeçalho do arquivo por setor.
# Os códigos são fixados depois de conferidos.

suppressPackageStartupMessages({ library(jsonlite); library(readxl) })
source("R/00_publicar_camada.R")
source("R/00_ibge_ftp.R")

BASE <- "https://ftp.ibge.gov.br/Censos/Censo_Demografico_2022/Agregados_por_Setores_Censitarios_Caracteristicas_urbanisticas_do_entorno_dos_domicilios/"
PASTA <- "dados/brutos/entorno"
COD_MUN <- "3304557"

itens <- listar(BASE)
message("Conteúdo da pasta:\n  ", paste(basename(itens), collapse = "\n  "))
for (d in itens[grepl("/$", itens)]) message("  ", basename(d), "/:\n    ", paste(basename(listar(d)), collapse = "\n    "))

dic_zip <- baixar_ibge(achar(BASE, "^dicionario.*\\.zip$")[1], PASTA)
xlsx <- utils::unzip(dic_zip, exdir = file.path(PASTA, "dicionarios"), overwrite = TRUE)
message("Dicionários: ", paste(basename(xlsx), collapse = ", "))
for (arq in xlsx[grepl("\\.xlsx$", xlsx)]) {
  for (aba in excel_sheets(arq)) {
    d <- as.data.frame(read_excel(arq, sheet = aba, col_names = FALSE, .name_repair = "minimal"))
    linhas <- apply(d, 1, function(r) paste(stats::na.omit(as.character(r)), collapse = " | "))
    message("== ", basename(arq), " [", aba, "] ", length(linhas), " linhas; primeiras 12:")
    message("  ", paste(utils::head(linhas, 12), collapse = "\n  "))
    hit <- grep("arboriz|árvore|arvore", linhas, ignore.case = TRUE, value = TRUE)
    message("-- linhas com arborização (", length(hit), "):\n  ", paste(hit, collapse = "\n  "))
  }
}

zips <- grep("domic|morad", listar(paste0(BASE, "Agregados_por_Setor_csv/")), value = TRUE)
message("Arquivos por setor (csv): ", paste(basename(zips), collapse = ", "))
for (z in zips) {
  arq <- baixar_ibge(z, PASTA)
  conteudo <- utils::unzip(arq, list = TRUE)
  message("== ", basename(arq), ":\n  ", paste(conteudo$Name, round(conteudo$Length / 1e6, 1), "MB", collapse = "\n  "))
  for (csv in conteudo$Name[grepl("\\.csv$", conteudo$Name, ignore.case = TRUE)]) {
    utils::unzip(arq, files = csv, exdir = PASTA, overwrite = TRUE)
    f <- file.path(PASTA, csv)
    cab <- readLines(f, n = 1, warn = FALSE)
    message("  ", csv, " — cabeçalho: ", substr(cab, 1, 2000))
    l <- system(paste0("grep -m 3 '^\"\\?", COD_MUN, "' ", shQuote(f)), intern = TRUE)
    message("  primeiras linhas do Rio:\n    ", paste(substr(l, 1, 600), collapse = "\n    "))
  }
}
