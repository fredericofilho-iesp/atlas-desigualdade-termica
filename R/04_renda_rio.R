# Atlas de Desigualdade Térmica — renda do responsável por setor (Rio)
# Executar na raiz do repositório: Rscript R/04_renda_rio.R
# Requer: install.packages(c("jsonlite", "readxl"))
#
# Fonte: IBGE, Censo Demográfico 2022, "Agregados por Setores Censitários —
#        Rendimento do Responsável" (resultados do universo).
#        https://ftp.ibge.gov.br/Censos/Censo_Demografico_2022/Agregados_por_Setores_Censitarios_Rendimento_do_Responsavel/
#
# O que é medido (dicionário IBGE, V06004 e V06006): valor do rendimento
# nominal médio e mediano mensal das pessoas responsáveis COM rendimentos por
# domicílios particulares permanentes ocupados (DPPO), em R$ de julho de 2022.
# Responsáveis sem rendimento não entram na média: em setores com muitos
# responsáveis sem renda, o valor superestima o nível do setor.
# NÃO é renda domiciliar per capita: é um indicador do nível socioeconômico
# do setor. Também apresentamos o valor em salários mínimos (R$ 1.212,00).
#
# O script lê o dicionário oficial e mostra no log a descrição de cada
# variável usada, para conferência. Valores suprimidos pelo IBGE (sigilo)
# ficam como ausentes, nunca como zero.
#
# Saídas: dados/indicadores/rio/{renda_media_resp, renda_mediana_resp}.{csv,json}
#         dados/indicadores/rio/_apoio_domicilios.csv (peso para as análises)

suppressPackageStartupMessages({ library(jsonlite); library(readxl) })
source("R/00_publicar_camada.R")
options(timeout = 1800)

BASE <- "https://ftp.ibge.gov.br/Censos/Censo_Demografico_2022/Agregados_por_Setores_Censitarios_Rendimento_do_Responsavel/"
COD_MUN <- "3304557"
SALARIO_MINIMO_2022 <- 1212
VARS <- c(domicilios = "V06001", media = "V06004", mediana = "V06006")

dir.create("dados/brutos/renda", recursive = TRUE, showWarnings = FALSE)

# ---- localizar arquivos na pasta do IBGE (nomes trazem a data da versão) ----
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
baixar <- function(url) {
  dest <- file.path("dados/brutos/renda", utils::URLdecode(basename(url)))
  if (!file.exists(dest)) download.file(url, dest, mode = "wb", method = "libcurl")
  dest
}

# Há um arquivo por recorte (setores, bairros, distritos...): pegar o de setores.
zip_url <- achar(BASE, "^Agregados_por_setores_renda.*csv.*\\.zip$")
dic_url <- achar(BASE, "dicionario.*\\.xlsx$")
message("Arquivos encontrados:\n  ", paste(c(zip_url, dic_url), collapse = "\n  "))
if (!length(zip_url)) message("Conteúdo da pasta:\n  ", paste(listar(BASE), collapse = "\n  "))
stopifnot(length(zip_url) >= 1)
zip_url <- sort(zip_url, decreasing = TRUE)[1]   # versão mais recente

# ---- dicionário: conferir o significado das variáveis ----
if (length(dic_url)) {
  dic_arq <- baixar(sort(dic_url, decreasing = TRUE)[1])
  for (aba in excel_sheets(dic_arq)) {
    d <- as.data.frame(read_excel(dic_arq, sheet = aba, col_names = FALSE, .name_repair = "minimal"))
    linhas <- apply(d, 1, function(r) paste(stats::na.omit(as.character(r)), collapse = " | "))
    hit <- grep("V0600[0-9]", linhas, value = TRUE)
    if (length(hit)) message("Dicionário [", aba, "]:\n  ", paste(hit, collapse = "\n  "))
  }
}

# ---- dados ----
zip_arq <- baixar(zip_url)
csvs <- utils::unzip(zip_arq, list = TRUE)$Name
csv <- csvs[grepl("\\.csv$", csvs, ignore.case = TRUE)][1]
utils::unzip(zip_arq, files = csv, exdir = "dados/brutos/renda", overwrite = TRUE)
arq <- file.path("dados/brutos/renda", csv)

primeira <- readLines(arq, n = 1, warn = FALSE)
sep <- if (lengths(regmatches(primeira, gregexpr(";", primeira))) >= lengths(regmatches(primeira, gregexpr(",", primeira)))) ";" else ","
tab <- utils::read.csv(arq, sep = sep, colClasses = "character", check.names = FALSE,
                       fileEncoding = "latin1")
names(tab) <- toupper(trimws(gsub('"', "", names(tab))))
message("Colunas: ", paste(names(tab), collapse = ", "))
message("Linhas (Brasil): ", nrow(tab))
stopifnot("CD_SETOR" %in% names(tab), all(VARS[c("domicilios", "media")] %in% names(tab)))

numero <- function(x) {
  x <- trimws(x)
  x[x %in% c("", "X", "x", "-", ".", "..", "...")] <- NA
  if (sep == ";") x <- sub(",", ".", x, fixed = TRUE)   # vírgula decimal, se houver
  suppressWarnings(as.numeric(x))
}

rio <- tab[substr(tab$CD_SETOR, 1, 7) == COD_MUN, ]
message("Setores do município do Rio no arquivo: ", nrow(rio))

malha <- readRDS(if (file.exists("dados/brutos/rio_setores_2022.rds")) "dados/brutos/rio_setores_2022.rds" else {
  source("R/01_importar_ibge.R"); "dados/brutos/rio_setores_2022.rds" })
setores <- as.character(malha$CD_SETOR)
i <- match(setores, rio$CD_SETOR)
message("Setores da malha com linha no arquivo de renda: ", sum(!is.na(i)), "/", length(setores))

saida <- data.frame(
  CD_SETOR = setores,
  domicilios = numero(rio[[VARS[["domicilios"]]]])[i],
  renda_media_resp = round(numero(rio[[VARS[["media"]]]])[i], 2),
  renda_mediana_resp = if (VARS[["mediana"]] %in% names(rio)) round(numero(rio[[VARS[["mediana"]]]])[i], 2) else NA_real_
)
saida$renda_media_resp[!is.na(saida$domicilios) & saida$domicilios == 0] <- NA
qs <- function(v) paste(names(q <- round(stats::quantile(v, c(0, .1, .5, .9, 1), na.rm = TRUE))), q, collapse = "  ")
message("Renda média do responsável (R$): ", qs(saida$renda_media_resp),
        " | setores com valor: ", sum(is.finite(saida$renda_media_resp)))
message("Renda mediana do responsável (R$): ", qs(saida$renda_mediana_resp),
        " | setores com valor: ", sum(is.finite(saida$renda_mediana_resp)))
message("Domicílios (responsáveis em DPPO): ", sum(saida$domicilios, na.rm = TRUE))

# Peso para as análises (não aparece como indicador no mapa).
dir.create("dados/indicadores/rio", recursive = TRUE, showWarnings = FALSE)
utils::write.csv(saida[, c("CD_SETOR", "domicilios")], "dados/indicadores/rio/_apoio_domicilios.csv",
                 row.names = FALSE, na = "")

fonte <- c(en = "IBGE, 2022 Census (universe), income of the household head",
           pt = "IBGE, Censo 2022 (universo), rendimento do responsável",
           es = "IBGE, Censo 2022 (universo), ingreso del responsable del hogar")
periodo <- c(en = "July 2022 (nominal R$)", pt = "julho de 2022 (R$ nominais)", es = "julio de 2022 (R$ nominales)")
nota_sm <- function(lang) switch(lang,
  en = paste0("1 minimum wage = R$ ", SALARIO_MINIMO_2022),
  pt = paste0("1 salário mínimo = R$ ", format(SALARIO_MINIMO_2022, big.mark = ".")),
  es = paste0("1 salario mínimo = R$ ", format(SALARIO_MINIMO_2022, big.mark = ".")))

inds <- list(
  indicador("renda_media_resp",
    rotulo = c(en = "Average income of household heads",
               pt = "Renda média do responsável pelo domicílio",
               es = "Ingreso medio del responsable del hogar"),
    unidade = "R$", paleta = "renda", dimensao = "sensibilidade", casas_decimais = 0,
    fonte = fonte, periodo = periodo, ordem = 20,
    metodo = c(en = paste0("Mean monthly nominal income of household heads with income, in occupied private households (", nota_sm("en"), "). Heads without income are excluded. Not per capita income."),
               pt = paste0("Rendimento nominal mensal médio das pessoas responsáveis com rendimentos, em domicílios particulares ocupados (", nota_sm("pt"), "). Responsáveis sem rendimento não entram. Não é renda per capita."),
               es = paste0("Ingreso nominal mensual medio de los responsables con ingresos, en hogares particulares ocupados (", nota_sm("es"), "). Se excluyen los responsables sin ingresos. No es ingreso per cápita.")))
)
if (any(is.finite(saida$renda_mediana_resp))) inds[[2]] <- indicador("renda_mediana_resp",
    rotulo = c(en = "Median income of household heads",
               pt = "Renda mediana do responsável pelo domicílio",
               es = "Ingreso mediano del responsable del hogar"),
    unidade = "R$", paleta = "renda", dimensao = "sensibilidade", casas_decimais = 0,
    fonte = fonte, periodo = periodo, ordem = 21,
    metodo = c(en = "Median monthly nominal income of household heads with income. Not per capita income.",
               pt = "Rendimento nominal mensal mediano das pessoas responsáveis com rendimentos. Não é renda per capita.",
               es = "Ingreso nominal mensual mediano de los responsables con ingresos. No es ingreso per cápita."))

salvar_indicadores(saida, escala = "rio", id = "CD_SETOR", indicadores = inds)
