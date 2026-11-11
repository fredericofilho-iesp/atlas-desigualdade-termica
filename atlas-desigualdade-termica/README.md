# Atlas Interativo de Desigualdade Térmica

Protótipo **v0.1**, focado inicialmente no município do Rio de Janeiro. O site contém um mapa-base interativo; **ainda não contém indicadores de temperatura, renda, vegetação ou geometrias censitárias**.

## Publicação via GitHub Pages

1. Envie os arquivos e pastas deste projeto à raiz da branch `main` do repositório `fredericofilho-iesp/atlas-desigualdade-termica`.
2. Em **Settings → Pages → Build and deployment**, escolha **Deploy from a branch**, `main`, `/ (root)` e salve.
3. Aguarde o workflow de publicação e abra o endereço indicado pelo GitHub Pages.

## Próximas etapas

- Adquirir e validar malhas oficiais de setores censitários de 2022 (IBGE).
- Verificar disponibilidade de indicadores de renda por setor censitário e seus metadados.
- Processar temperatura superficial com resolução, período e metodologia documentados.
- Produzir camadas otimizadas para navegação e comparações territoriais.

## Limitações

Este protótipo utiliza Leaflet e mosaicos do OpenStreetMap, carregados via internet. Não deve ser interpretado como um mapa de desigualdade térmica já calculado.
