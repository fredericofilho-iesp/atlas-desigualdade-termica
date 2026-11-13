# Atlas de Desigualdade Térmica — publicação de camadas para o site
#
# publicar_camada() é a ponte entre o R e o mapa: recebe um objeto sf com as
# colunas de indicadores, grava um GeoJSON enxuto e um manifesto (camada.json)
# que o site lê para montar o seletor de indicadores, as cores e a legenda.
# Contrato completo em docs/CONTRATO_DE_DADOS.md.
#
# Textos multilíngues: qualquer campo de texto aceita um vetor nomeado
# c(en = "...", pt = "...", es = "..."). O site mostra o idioma escolhido
# pelo visitante (com inglês como reserva). Um texto simples também vale.
#
# Uso típico:
#   source("R/00_publicar_camada.R")
#   publicar_camada(rio, escala = "rio", id = "CD_SETOR",
#     unidade        = c(en = "Census tract", pt = "Setor censitário", es = "Sector censal"),
#     unidade_plural = c(en = "Census tracts", pt = "Setores censitários", es = "Sectores censales"),
#     fonte_geometria = c(en = "IBGE 2022 census tracts", pt = "Malha de setores IBGE 2022",
#                         es = "Sectores censales IBGE 2022"),
#     fonte_curta = "IBGE 2022",
#     indicadores = list(
#       indicador("lst_verao",
#         rotulo = c(en = "Summer land surface temperature",
#                    pt = "Temperatura da superfície no verão",
#                    es = "Temperatura de superficie en verano"),
#         unidade = "°C", paleta = "calor", casas_decimais = 1,
#         fonte = "Landsat 8/9 (USGS)",
#         periodo = c(en = "Dec–Mar 2023–2025", pt = "dez.–mar. 2023–2025", es = "dic.–mar. 2023–2025"))))

suppressPackageStartupMessages({ library(sf); library(jsonlite) })

# Vetor nomeado c(en=, pt=, es=) -> objeto JSON {"en":..., "pt":..., "es":...}.
txt <- function(x) {
  if (is.null(x)) return(NULL)
  if (!is.null(names(x)) && all(nzchar(names(x)))) return(as.list(x))
  x
}

#' Metadados de um indicador. `id` deve ser o nome da coluna no objeto sf.
#' paleta: "calor", "renda", "verde", "pessoas" ou "divergente".
#' quebras: limites fixos das classes (opcional). Sem eles, usa `classificacao`.
#' ordem: posição no seletor do site (menor aparece primeiro).
#' tipo/eixos: para indicadores especiais, como o bivariado (ver R/05_calor_renda_rio.R).
indicador <- function(id, rotulo, unidade = NULL, paleta = "calor",
                      dimensao = c("exposicao", "sensibilidade", "adaptacao", "contexto"),
                      fonte = NULL, periodo = NULL, metodo = NULL,
                      casas_decimais = 1, n_classes = 5,
                      classificacao = c("quantis", "intervalos_iguais"),
                      quebras = NULL, ordem = 50, tipo = NULL, eixos = NULL) {
  ind <- list(id = id, rotulo = txt(rotulo), unidade = txt(unidade), paleta = paleta,
              dimensao = match.arg(dimensao), fonte = txt(fonte), periodo = txt(periodo),
              metodo = txt(metodo), casas_decimais = casas_decimais,
              n_classes = n_classes, classificacao = match.arg(classificacao),
              ordem = ordem)
  if (!is.null(quebras)) { ind$quebras_fixas <- sort(quebras); ind$classificacao <- "manual" }
  # tipo = "bivariado": valores 1–9 (tercil do eixo y − 1) × 3 + tercil do eixo x;
  # `eixos` descreve os dois indicadores e os limites dos tercis para a legenda.
  if (!is.null(tipo)) { ind$tipo <- tipo; ind$eixos <- eixos; ind$classificacao <- NULL; ind$n_classes <- NULL }
  Filter(Negate(is.null), ind)
}

#' Classes bivariadas 3 × 3 (1–9): (classe de y − 1) × 3 + classe de x.
#' Tercis ponderados por `w` (cada terço reúne ~1/3 do peso); `quebras_x` fixa os
#' limites do eixo x; `inverso_x` inverte o eixo x (ex.: % de um grupo, para que a
#' cor de destaque — canto magenta — marque "mais quente e com mais pessoas do grupo").
classe_bivariada <- function(y, x, w, quebras_x = NULL, inverso_x = FALSE) {
  ok <- is.finite(y) & is.finite(x) & is.finite(w) & w > 0
  terc <- function(v, p) { o <- order(v); meio <- (cumsum(p[o]) - p[o] / 2) / sum(p)
    g <- integer(length(v)); g[o] <- pmin(3L, floor(meio * 3) + 1L); g }
  lim <- function(v, g) vapply(1:2, function(j) (max(v[g == j]) + min(v[g == j + 1])) / 2, 0)
  ty <- terc(y[ok], w[ok])
  tx <- if (is.null(quebras_x)) terc(x[ok], w[ok]) else findInterval(x[ok], quebras_x) + 1L
  lx <- if (is.null(quebras_x)) lim(x[ok], tx) else quebras_x
  ly <- lim(y[ok], ty)
  if (inverso_x) tx <- 4L - tx
  cl <- rep(NA_real_, length(y)); cl[ok] <- (ty - 1) * 3 + tx
  list(classe = cl, lim_y = ly, lim_x = lx, inverso_x = inverso_x)
}

#' Metadados de um indicador bivariado a partir de classe_bivariada().
#' y, x: listas com indicador, unidade, rotulo {en,pt,es}, classes {en,pt,es: 3 rótulos
#' na ordem das colunas/linhas da legenda}, casas (decimais dos limites).
indicador_bivariado <- function(id, rotulo, b, y, x, nota, ordem, fonte, metodo, periodo = NULL) {
  y$limites <- round(b$lim_y, y$casas %||% 1); x$limites <- round(b$lim_x, x$casas %||% 1)
  x$inverso <- isTRUE(b$inverso_x)
  indicador(id, rotulo = rotulo, paleta = "bivariada", dimensao = "exposicao", casas_decimais = 0, ordem = ordem,
            tipo = "bivariado", eixos = list(y = y, x = x, nota = nota), fonte = fonte, metodo = metodo, periodo = periodo)
}
if (!exists("%||%")) `%||%` <- function(a, b) if (is.null(a) || !length(a)) b else a

#' Guarda indicadores já calculados em dados/indicadores/<escala>/<id>.{csv,json}.
#' tabela: data.frame com a coluna identificadora e uma coluna por indicador.
#' Esses arquivos são pequenos e versionados; publicar a camada só os junta à malha.
salvar_indicadores <- function(tabela, escala, id, indicadores, dir = "dados/indicadores") {
  d <- file.path(dir, escala)
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
  for (ind in indicadores) {
    out <- data.frame(as.character(tabela[[id]]), as.numeric(tabela[[ind$id]]))
    names(out) <- c(id, ind$id)
    utils::write.csv(out, file.path(d, paste0(ind$id, ".csv")), row.names = FALSE, na = "")
    write_json(ind, file.path(d, paste0(ind$id, ".json")),
               auto_unbox = TRUE, pretty = TRUE, digits = NA)
    message("Indicador salvo: ", escala, "/", ind$id, " (", sum(is.finite(out[[2]])), " valores)")
  }
  invisible(TRUE)
}

#' Junta a `x` todos os indicadores salvos para a escala.
#' Retorna list(x = sf com as colunas, indicadores = lista de metadados).
carregar_indicadores <- function(x, escala, id, dir = "dados/indicadores") {
  arqs <- list.files(file.path(dir, escala), "\\.json$", full.names = TRUE)
  metas <- lapply(arqs, function(a) read_json(a, simplifyVector = TRUE))
  if (length(metas)) metas <- metas[order(vapply(metas, function(m) if (is.null(m$ordem)) 50 else m$ordem, 0),
                                          vapply(metas, `[[`, "", "id"))]
  for (m in metas) {
    tab <- utils::read.csv(file.path(dir, escala, paste0(m$id, ".csv")),
                           colClasses = stats::setNames("character", id))
    x[[m$id]] <- as.numeric(tab[[m$id]])[match(as.character(x[[id]]), tab[[id]])]
  }
  list(x = x, indicadores = metas)
}

# Mantém só a parte poligonal de geometrias mistas (GEOMETRYCOLLECTION com
# polígonos e linhas soltas), que surgem ao corrigir ou arredondar geometrias.
so_poligonos <- function(x) {
  gc <- st_geometry_type(x) == "GEOMETRYCOLLECTION"
  if (!any(gc)) return(x)
  g <- st_geometry(x)
  for (k in which(gc)) {
    p <- st_collection_extract(g[k], "POLYGON", warn = FALSE)
    g[k] <- if (length(p)) st_union(p) else st_sfc(st_multipolygon(), crs = st_crs(g))
  }
  st_geometry(x) <- g
  message("Geometrias mistas convertidas em polígonos: ", sum(gc))
  x
}

calcular_quebras <- function(x, n = 5, metodo = "quantis") {
  x <- x[is.finite(x)]
  if (length(x) < n) return(numeric(0))
  q <- if (metodo == "quantis") {
    stats::quantile(x, probs = seq(0, 1, length.out = n + 1)[-c(1, n + 1)],
                    names = FALSE, type = 7)
  } else {
    seq(min(x), max(x), length.out = n + 1)[-c(1, n + 1)]
  }
  unique(q)  # distribuições com muitos empates podem gerar menos classes
}

publicar_camada <- function(x, escala, id, indicadores = list(),
                            rotulo = NULL,
                            unidade = "Unidade", unidade_plural = "Unidades",
                            fonte_geometria = NULL, fonte_curta = NULL,
                            simplificar_m = NULL, crs_metrico = 31983,
                            casas_coord = 5, dir_saida = "dados/processados") {
  stopifnot(inherits(x, "sf"), id %in% names(x))
  ids_ind <- vapply(indicadores, `[[`, "", "id")
  faltando <- setdiff(ids_ind, names(x))
  if (length(faltando)) stop("Colunas ausentes no objeto sf: ", paste(faltando, collapse = ", "))
  if (anyDuplicated(x[[id]])) stop("Identificador '", id, "' tem valores duplicados.")

  manter <- unique(c(id, rotulo, ids_ind))
  x <- x[, manter]
  x[[id]] <- as.character(x[[id]])

  if (!is.null(simplificar_m)) {
    x <- st_transform(x, crs_metrico)
    x <- st_simplify(x, dTolerance = simplificar_m, preserveTopology = TRUE)
  }
  x <- st_make_valid(st_transform(x, 4326))
  x <- so_poligonos(x)

  # Arredonda indicadores e completa metadados de classificação.
  for (i in seq_along(indicadores)) {
    ind <- indicadores[[i]]
    v <- as.numeric(x[[ind$id]])
    x[[ind$id]] <- round(v, ind$casas_decimais + 2)
    if (!is.null(ind$tipo)) { indicadores[[i]]$n_validos <- sum(is.finite(v)); next }
    q <- if (!is.null(ind$quebras_fixas)) ind$quebras_fixas else
      round(calcular_quebras(v, ind$n_classes, ind$classificacao), ind$casas_decimais + 1)
    indicadores[[i]]$quebras <- I(q)  # I(): sempre lista JSON, mesmo com 1 valor
    indicadores[[i]]$quebras_fixas <- NULL
    # "quantis" ou "intervalos_iguais"; o site traduz e conta as classes.
    indicadores[[i]]$classificacao <- ind$classificacao
    indicadores[[i]]$n_validos <- sum(is.finite(v))
    indicadores[[i]]$n_classes <- NULL
  }

  dir <- file.path(dir_saida, escala)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  arq_geo <- file.path(dir, "unidades.geojson")
  gravar <- function(obj) st_write(obj, arq_geo, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE,
                                   layer_options = c(paste0("COORDINATE_PRECISION=", casas_coord), "RFC7946=YES"))
  gravar(x)
  # O arredondamento das coordenadas na gravação pode transformar lascas de
  # polígono em linhas (GEOMETRYCOLLECTION). Relê, limpa e regrava se preciso.
  relido <- st_read(arq_geo, quiet = TRUE)
  if (any(st_geometry_type(relido) == "GEOMETRYCOLLECTION")) {
    st_geometry(x) <- st_geometry(so_poligonos(relido))
    gravar(x)
  }

  manifesto <- list(
    versao_contrato = 2,
    escala = escala,
    gerado_em = format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z"),
    unidade = txt(unidade), unidade_plural = txt(unidade_plural),
    fonte_geometria = txt(fonte_geometria), fonte_curta = txt(fonte_curta),
    quantidade_unidades = nrow(x),
    geometria = list(tipo = "geojson", url = "unidades.geojson",
                     id = id, rotulo = if (is.null(rotulo)) id else rotulo),
    indicadores = unname(indicadores)
  )
  write_json(manifesto, file.path(dir, "camada.json"),
             auto_unbox = TRUE, pretty = TRUE, null = "null", digits = NA)

  tam <- round(file.size(arq_geo) / 1024^2, 1)
  message("Camada '", escala, "': ", nrow(x), " unidades, ", length(indicadores),
          " indicador(es), ", tam, " MiB")
  if (tam > 40) warning("GeoJSON acima de 40 MiB: considere PMTiles para esta escala.")
  invisible(manifesto)
}
