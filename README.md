
<!-- README.md is generated from README.Rmd. Please edit that file -->

# ccc_datos

<!-- badges: start -->
<!-- badges: end -->

This repository contains the scripts I used for scraping the Colombian
Constitutional Court’s website.

The `textos/` directory is not included in the repository. It has 26917
documents.

All relevant data will be contained in the `data/` directory.

``` r
fs::dir_tree("data/")
#> data/
#> ├── metadata.rds
#> ├── seeds.rds
#> └── seeds2.rds
```

The `seeds.rds` file contains cases that show up in the old search
engine when we search for “corte” (court, in Spanish).

The `seeds2.rds` file contains cases that show up in the new search
engine when we search for “corte”.

The `metadata.rds` file contains all case-level information.

``` r
dplyr::glimpse(readr::read_rds("data/metadata.rds"))
#> Rows: 26,930
#> Columns: 8
#> $ id                                 <chr> "T-365-21", "T-353-21", "T-352-21",…
#> $ type                               <chr> "T", "T", "T", "T", "T", "T", "T", …
#> $ year                               <int> 2021, 2021, 2021, 2021, 2021, 2021,…
#> $ date                               <date> 2021-10-25, 2021-10-15, 2021-10-14…
#> $ tipo                               <chr> "Tutela", "Tutela", "Tutela", "Tute…
#> $ resumen                            <chr> "En este caso Colpensiones aduce qu…
#> $ ponentes                           <list> "Alejandro Linares Cantillo", "Dia…
#> $ salvamentos_y_aclaraciones_de_voto <list> "", "", "José Fernando Reyes Cuart…
```

<img src="asdf.png" style="display: block; margin: auto;" />
