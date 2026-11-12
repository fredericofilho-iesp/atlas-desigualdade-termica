# Atlas de Desigualdade Térmica — arborização do entorno por setor (Rio)
# Executar na raiz do repositório: Rscript R/06_arborizacao_rio.R
# Requer: install.packages(c("jsonlite", "readxl"))
# Depende de: R/03 (temperatura) e R/04 (renda e domicílios) para as análises.
#
# Fonte: IBGE, Censo 2022, "Agregados por Setores Censitários — Características
#        urbanísticas do entorno dos domicílios", arquivo de MORADORES.
#        https://ftp.ibge.gov.br/Censos/Censo_Demografico_2022/Agregados_por_Setores_Censitarios_Caracteristicas_urbanisticas_do_entorno_dos_domicilios/
#
# Variáveis (dicionario_entorno_pessoas.xlsx): moradores em domicílios
# particulares permanentes ocupados, em setor escolhido para aplicação do
# entorno, segundo a arborização da face de quadra onde está o domicílio:
#   V05230 sem árvores · V05231 1–2 árvores · V05232 3–4 · V05233 5 ou mais
#   V05234 saltado (face não observada) — fica fora do denominador.
# Observação de campo do recenseador na face de quadra, não medida de copa.
#
# Indicadores (% dos moradores com face observada):
#   arv_com_arvores  faces com pelo menos 1 árvore
#   arv_5mais        faces com 5 ou mais árvores
# Setores sem pesquisa do entorno ou com menos de MIN_MORADORES moradores
# observados ficam sem dado.
#
# Análises (dados/processados/rio/arborizacao_resumo.json):
#   - % de moradores em faces com árvores, por quinto de renda (ponderado por domicílios)
#   - temperatura média da superfície por quinto de arborização (ponderado por moradores)

suppressPackageStartupMessages({ library(jsonlite) })
source("R/00_publicar_camada.R")
source("R/00_ibge_ftp.R")

BASE <- "https://ftp.ibge.gov.br/Censos/Censo_Demografico_2022/Agregados_por_Setores_Censitarios_Caracteristicas_urbanisticas_do_entorno_dos_domicilios/"
PASTA <- "dados/brutos/entorno"
COD_MUN <- "3304557"
MIN_MORADORES <- 20
VARS <- c(sem = "V05230", a1_2 = "V05231", a3_4 = "V05232", a5 = "V05233", saltado = "V05234")

if (!file.exists("dados/brutos/rio_setores_2022.rds")) local(source("R/01_importar_ibge.R", local = TRUE))
malha <- readRDS("dados/brutos/rio_setores_2022.rds")
setores <- as.character(malha$CD_SETOR)

# ---- dados ----
zip_url <- grep("setores_entorno_moradores.*\\.zip$", listar(paste0(BASE, "Agregados_por_Setor_csv/")), value = TRUE)[1]
stopifnot(!is.na(zip_url))
zip_arq <- baixar_ibge(zip_url, PASTA)
csv <- utils::unzip(zip_arq, list = TRUE)$Name
csv <- csv[grepl("\\.csv$", csv, ignore.case = TRUE, useBytes = TRUE)][1]
utils::unzip(zip_arq, files = csv, exdir = PASTA, overwrite = TRUE)
arq <- file.path(PASTA, csv)

# Lê só o cabeçalho e as linhas do município (arquivo nacional de ~65 MB).
cab <- gsub('"', "", strsplit(readLines(arq, n = 1, warn = FALSE), ";")[[1]])
linhas <- system(paste0("grep '^\"\\?", COD_MUN, "' ", shQuote(arq)), intern = TRUE)
tab <- utils::read.table(text = linhas, sep = ";", quote = '"', colClasses = "character",
                         col.names = cab, check.names = FALSE)
names(tab)[1] <- "CD_SETOR"
message("Colunas: ", paste(names(tab), collapse = ", "))
message("Setores do Rio no arquivo de entorno: ", nrow(tab))
stopifnot(all(VARS %in% names(tab)))
num <- function(x) { x <- trimws(x); x[x %in% c("", "X", "-", ".")] <- NA; suppressWarnings(as.numeric(x)) }

i <- match(setores, tab$CD_SETOR)
m <- sapply(VARS, function(v) num(tab[[v]])[i])
observados <- rowSums(m[, c("sem", "a1_2", "a3_4", "a5"), drop = FALSE])
ok <- is.finite(observados) & observados >= MIN_MORADORES
saida <- data.frame(
  CD_SETOR = setores,
  moradores_entorno = observados,
  arv_com_arvores = ifelse(ok, round(100 * (m[, "a1_2"] + m[, "a3_4"] + m[, "a5"]) / observados, 1), NA_real_),
  arv_5mais = ifelse(ok, round(100 * m[, "a5"] / observados, 1), NA_real_)
)
pct_saltado <- 100 * sum(m[, "saltado"], na.rm = TRUE) / sum(observados + m[, "saltado"], na.rm = TRUE)
qs <- function(v) paste(names(q <- round(stats::quantile(v, c(0, .1, .25, .5, .75, .9, 1), na.rm = TRUE), 1)), q, collapse = "  ")
cidade_com <- 100 * sum((m[, "a1_2"] + m[, "a3_4"] + m[, "a5"])[ok]) / sum(observados[ok])
cidade_5 <- 100 * sum(m[ok, "a5"]) / sum(observados[ok])
message("Setores com valor: ", sum(ok), "/", length(setores),
        " | moradores observados: ", sum(observados[ok]),
        " | faces saltadas: ", round(pct_saltado, 1), "% dos moradores")
message("Cidade: ", round(cidade_com, 1), "% dos moradores em faces com árvore; ",
        round(cidade_5, 1), "% em faces com 5+ árvores")
message("% com árvores por setor: ", qs(saida$arv_com_arvores))
message("% com 5+ árvores por setor: ", qs(saida$arv_5mais))

# ---- análises ----
ler <- function(id) utils::read.csv(file.path("dados/indicadores/rio", paste0(id, ".csv")),
                                    colClasses = c(CD_SETOR = "character"))
d <- Reduce(function(a, b) merge(a, b, by = "CD_SETOR", all.x = TRUE),
            list(saida, ler("lst_verao"), ler("renda_media_resp"), ler("_apoio_domicilios")))
grupos <- function(x, w, k) {
  o <- order(x); meio <- (cumsum(w[o]) - w[o] / 2) / sum(w)
  g <- integer(length(x)); g[o] <- pmin(k, floor(meio * k) + 1L); g
}

# (a) arborização por quinto de renda
a <- d[is.finite(d$arv_com_arvores) & is.finite(d$renda_media_resp) & is.finite(d$domicilios) & d$domicilios > 0, ]
a$q <- grupos(a$renda_media_resp, a$domicilios, 5)
por_renda <- lapply(1:5, function(q) { s <- a[a$q == q, ]
  list(quinto = q, setores = nrow(s), domicilios = sum(s$domicilios),
       arv_com_arvores = round(stats::weighted.mean(s$arv_com_arvores, s$domicilios), 1),
       arv_5mais = round(stats::weighted.mean(s$arv_5mais, s$domicilios), 1)) })

# (b) temperatura por quinto de arborização (ponderado por moradores observados)
b <- d[is.finite(d$arv_com_arvores) & is.finite(d$lst_verao), ]
b$q <- grupos(b$arv_5mais + b$arv_com_arvores / 1000, b$moradores_entorno, 5)  # desempate estável
por_arv <- lapply(1:5, function(q) { s <- b[b$q == q, ]
  list(quinto = q, setores = nrow(s), moradores = sum(s$moradores_entorno),
       arv_5mais_min = min(s$arv_5mais), arv_5mais_max = max(s$arv_5mais),
       lst_media = round(stats::weighted.mean(s$lst_verao, s$moradores_entorno), 2)) })
rho_lst <- stats::cor(b$arv_5mais, b$lst_verao, method = "spearman")
rho_renda <- stats::cor(a$arv_5mais, a$renda_media_resp, method = "spearman")

message("Arborização por quinto de renda (% moradores em faces com árvore / com 5+):")
for (r in por_renda) message(sprintf("  Q%d  %5.1f%%  %5.1f%%", r$quinto, r$arv_com_arvores, r$arv_5mais))
message("Temperatura por quinto de arborização (faces com 5+ árvores):")
for (r in por_arv) message(sprintf("  Q%d  %5.1f–%5.1f%%  %.2f °C", r$quinto, r$arv_5mais_min, r$arv_5mais_max, r$lst_media))
message(sprintf("Spearman (setores): 5+ árvores × temperatura %.2f | 5+ árvores × renda %.2f", rho_lst, rho_renda))

dir.create("dados/processados/rio", recursive = TRUE, showWarnings = FALSE)
write_json(list(
  gerado_em = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
  fonte = "IBGE, Censo 2022, características urbanísticas do entorno (moradores), V05230–V05234",
  setores_com_valor = sum(ok), cidade_com_arvores = round(cidade_com, 1), cidade_5mais = round(cidade_5, 1),
  faces_saltadas_pct_moradores = round(pct_saltado, 1),
  por_quinto_de_renda = por_renda, por_quinto_de_arborizacao = por_arv,
  spearman_5mais_lst = round(rho_lst, 3), spearman_5mais_renda = round(rho_renda, 3)
), "dados/processados/rio/arborizacao_resumo.json", auto_unbox = TRUE, pretty = TRUE, digits = NA)

# ---- indicadores ----
fonte <- c(en = "IBGE, 2022 Census, urban characteristics of the surroundings",
           pt = "IBGE, Censo 2022, características urbanísticas do entorno",
           es = "IBGE, Censo 2022, características urbanísticas del entorno")
periodo <- c(en = "2022", pt = "2022", es = "2022")
salvar_indicadores(saida, escala = "rio", id = "CD_SETOR", indicadores = list(
  indicador("arv_com_arvores",
    rotulo = c(en = "Residents on blocks with street trees",
               pt = "Moradores em faces de quadra com árvores",
               es = "Residentes en frentes de manzana con árboles"),
    unidade = "%", paleta = "verde", dimensao = "adaptacao", casas_decimais = 0,
    fonte = fonte, periodo = periodo, ordem = 40,
    metodo = c(en = "Share of residents whose block face has at least one tree, as observed by census enumerators (faces not observed are excluded)",
               pt = "Proporção de moradores cuja face de quadra tem ao menos uma árvore, segundo observação do recenseador (faces não observadas ficam fora)",
               es = "Proporción de residentes cuyo frente de manzana tiene al menos un árbol, según la observación del censista (se excluyen los frentes no observados)")),
  indicador("arv_5mais",
    rotulo = c(en = "Residents on blocks with 5+ street trees",
               pt = "Moradores em faces de quadra com 5 ou mais árvores",
               es = "Residentes en frentes de manzana con 5 o más árboles"),
    unidade = "%", paleta = "verde", dimensao = "adaptacao", casas_decimais = 0,
    fonte = fonte, periodo = periodo, ordem = 41,
    metodo = c(en = "Share of residents whose block face has 5 or more trees, as observed by census enumerators",
               pt = "Proporção de moradores cuja face de quadra tem 5 ou mais árvores, segundo observação do recenseador",
               es = "Proporción de residentes cuyo frente de manzana tiene 5 o más árboles, según la observación del censista"))
))

source("R/10_publicar_rio.R")
