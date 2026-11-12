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
#' paleta: "calor", "renda", "verde" ou "pessoas".
indicador <- function(id, rotulo, unidade = NULL, paleta = "calor",
                      dimensao = c("exposicao", "sensibilidade", "adaptacao", "contexto"),
                      fonte = NULL, periodo = NULL, metodo = NULL,
                      casas_decimais = 1, n_classes = 5,
                      classificacao = c("quantis", "intervalos_iguais")) {
  list(id = id, rotulo = txt(rotulo), unidade = txt(unidade), paleta = paleta,
       dimensao = match.arg(dimensao), fonte = txt(fonte), periodo = txt(periodo),
       metodo = txt(metodo), casas_decimais = casas_decimais,
       n_classes = n_classes, classificacao = match.arg(classificacao))
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

  # Arredonda indicadores e completa metadados de classificação.
  for (i in seq_along(indicadores)) {
    ind <- indicadores[[i]]
    v <- as.numeric(x[[ind$id]])
    x[[ind$id]] <- round(v, ind$casas_decimais + 2)
    q <- calcular_quebras(v, ind$n_classes, ind$classificacao)
    indicadores[[i]]$quebras <- round(q, ind$casas_decimais + 1)
    # "quantis" ou "intervalos_iguais"; o site traduz e conta as classes.
    indicadores[[i]]$classificacao <- ind$classificacao
    indicadores[[i]]$n_validos <- sum(is.finite(v))
    indicadores[[i]]$n_classes <- NULL
  }

  dir <- file.path(dir_saida, escala)
  dir.create(dir, recursive = TRUE, showWarnings = FALSE)
  arq_geo <- file.path(dir, "unidades.geojson")
  st_write(x, arq_geo, driver = "GeoJSON", delete_dsn = TRUE, quiet = TRUE,
           layer_options = c(paste0("COORDINATE_PRECISION=", casas_coord), "RFC7946=YES"))

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
