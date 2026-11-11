# Atlas Interativo de Desigualdade Térmica

Plataforma acadêmica em desenvolvimento para explorar exposição térmica e desigualdades socioespaciais em quatro escalas: município do Rio de Janeiro, estado do Rio de Janeiro, Brasil e América Latina.

## Estado atual — v0.1

O arquivo `index.html` implementa um **protótipo cartográfico navegável**, centrado no Rio de Janeiro, com Leaflet e OpenStreetMap. **Ainda não contém dados de temperatura, renda, cobertura vegetal ou setores censitários.** As opções futuras estão desabilitadas intencionalmente para evitar confundir o mapa-base com resultados científicos.

## Visualização

Após ativar GitHub Pages (Settings → Pages → Deploy from a branch → main / root), o site deverá aparecer em:

https://fredericofilho-iesp.github.io/atlas-desigualdade-termica/

## Etapas seguintes

1. Importar malha oficial dos setores censitários do IBGE (2022).
2. Validar e integrar indicadores populacionais e socioeconômicos.
3. Selecionar produto térmico e agregar valores por unidade territorial, documentando resolução e período.
4. Adicionar mapas temáticos, legendas, filtros e painéis.
5. Expandir para escalas estadual, nacional e latino-americana.

## Princípios metodológicos

- Não confundir temperatura superficial com temperatura do ar.
- Publicar apenas indicadores com fonte, período, unidade e método verificáveis.
- Evitar interpretações causais a partir de correlações ecológicas.
- Preservar scripts e metadados para reprodução.

## Tecnologias

HTML, CSS, JavaScript, Leaflet e OpenStreetMap nesta versão. Processamento geoespacial futuro em R.
