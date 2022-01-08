
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
#> ├── citations.rds
#> ├── metadata.rds
#> ├── seeds.rds
#> └── seeds2.rds
```

-   `seeds.rds` contains cases that show up in the old search engine
    when we search for “corte” (or *court*, in Spanish).

-   `seeds2.rds` file contains cases that show up in the new search
    engine when we search for “corte”.

-   `metadata.rds` file contains all available case-level information.

    ``` r
    dplyr::glimpse(readr::read_rds("data/metadata.rds"))
    #> Rows: 26,918
    #> Columns: 8
    #> $ id                                 <chr> "T-012-92", "T-001-92", "C-004-92",…
    #> $ type                               <chr> "T", "T", "C", "T", "T", "C", "T", …
    #> $ year                               <int> 1992, 1992, 1992, 1992, 1992, 1992,…
    #> $ date                               <date> 1992-02-25, 1992-04-03, 1992-05-07…
    #> $ tipo                               <chr> "Tutela", "Tutela", "Constitucional…
    #> $ resumen                            <chr> NA, NA, NA, NA, NA, NA, NA, NA, NA,…
    #> $ ponentes                           <list> "José Gregorio Hernández Galindo",…
    #> $ salvamentos_y_aclaraciones_de_voto <list> NA, NA, NA, NA, NA, NA, NA, NA, NA…
    ```

<!-- -->

-   `citations.rds` file contains the edge list of citations.

    ``` r
    el <- readr::read_rds("data/citations.rds")
    dplyr::glimpse(el)
    #> Rows: 949,087
    #> Columns: 6
    #> $ from      <chr> "C-001-18", "C-001-18", "C-001-18", "C-001-18", "C-001-18", …
    #> $ to        <chr> "C-458-15", "C-135-17", "C-042-17", "C-390-17", "C-1235-05",…
    #> $ from_year <int> 2018, 2018, 2018, 2018, 2018, 2018, 2018, 2018, 2018, 2018, …
    #> $ to_year   <int> 2015, 2017, 2017, 2017, 2005, 2005, 2005, 2005, 2005, 1996, …
    #> $ from_date <date> 2018-01-24, 2018-01-24, 2018-01-24, 2018-01-24, 2018-01-24,…
    #> $ to_date   <date> 2015-07-22, 2017-03-01, 2017-02-01, 2017-06-14, 2005-11-29,…
    ```

    Note that some cases cite other cases multiple times.

    ``` r
    dplyr::count(el, from, to, sort = TRUE) |> head(n = 10)
    #> # A tibble: 10 × 3
    #>    from      to           n
    #>    <chr>     <chr>    <int>
    #>  1 SU-214-16 C-577-11   256
    #>  2 C-088-20  C-355-06   226
    #>  3 C-080-18  C-007-18   211
    #>  4 C-080-18  C-674-17   181
    #>  5 SU-096-18 C-355-06   152
    #>  6 T-388-13  T-153-98   149
    #>  7 C-077-17  C-644-12   133
    #>  8 T-444-14  C-577-11   124
    #>  9 T-109-19  C-258-13   121
    #> 10 SU-575-19 C-258-13   119
    ```

------------------------------------------------------------------------

<img src="weekly-cases.png" style="display: block; margin: auto;" />
