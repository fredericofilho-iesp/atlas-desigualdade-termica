# Atlas de Desigualdade Térmica — acesso ao FTP do IBGE
# Os nomes dos arquivos trazem a data da versão (ex.: ..._20260508_csv.zip),
# então os scripts procuram pelo padrão do nome em vez de fixar a URL.
#   listar(url)               itens de uma pasta
#   achar(url, padrao)        arquivos cujo nome casa com `padrao` (desce 2 níveis)
#   baixar_ibge(url, pasta)   baixa uma vez e reaproveita o arquivo local
options(timeout = max(1800, getOption("timeout")))

listar <- function(url) {
  # As listagens do FTP do IBGE vêm em latin1; ler como bytes evita erro de codificação.
  h <- paste(readLines(url, warn = FALSE), collapse = "\n")
  h <- iconv(h, from = "latin1", to = "UTF-8", sub = "")
  l <- regmatches(h, gregexpr('href="[^"?][^"]*"', h, useBytes = TRUE))[[1]]
  l <- gsub('^href="|"$', "", l)
  l <- l[!grepl("^/|^\\.\\./?$|^https?:", l)]
  unique(paste0(url, l))
}
achar <- function(url, padrao, profundidade = 2) {
  itens <- listar(url)
  ok <- itens[grepl(padrao, basename(itens), ignore.case = TRUE)]
  if (length(ok)) return(ok)
  if (profundidade > 0) for (d in itens[grepl("/$", itens)]) {
    r <- achar(d, padrao, profundidade - 1)
    if (length(r)) return(r)
  }
  character(0)
}
baixar_ibge <- function(url, pasta) {
  dir.create(pasta, recursive = TRUE, showWarnings = FALSE)
  dest <- file.path(pasta, utils::URLdecode(basename(url)))
  if (!file.exists(dest)) download.file(url, dest, mode = "wb", method = "libcurl")
  dest
}

# Lê um CSV de agregados do IBGE (";", aspas, latin1) e devolve só as linhas
# cujo código (1ª coluna) começa com `prefixo` (ex.: código do município).
# A 1ª coluna é renomeada para CD_SETOR; demais colunas ficam como texto.
ler_csv_ibge <- function(arquivo, prefixo = NULL) {
  tab <- utils::read.table(arquivo, sep = ";", quote = '"', header = TRUE, colClasses = "character",
                           fileEncoding = "latin1", check.names = FALSE, comment.char = "")
  names(tab) <- toupper(trimws(names(tab)))
  names(tab)[1] <- "CD_SETOR"
  tab$CD_SETOR <- trimws(tab$CD_SETOR)
  if (!is.null(prefixo)) tab <- tab[startsWith(tab$CD_SETOR, prefixo), , drop = FALSE]
  tab
}

# Converte texto do IBGE em número: "X" (sigilo), "-", "." e vazio viram NA;
# aceita vírgula decimal.
numero_ibge <- function(x) {
  x <- trimws(x)
  x[x %in% c("", "X", "x", "-", ".", "..", "...")] <- NA
  suppressWarnings(as.numeric(sub(",", ".", x, fixed = TRUE)))
}

# Extrai o primeiro .csv de um zip do IBGE (nomes podem vir em latin1).
extrair_csv <- function(zip, pasta) {
  n <- utils::unzip(zip, list = TRUE)$Name
  n <- n[grepl("\\.csv$", n, ignore.case = TRUE, useBytes = TRUE)][1]
  utils::unzip(zip, files = n, exdir = pasta, overwrite = TRUE)
  file.path(pasta, n)
}
