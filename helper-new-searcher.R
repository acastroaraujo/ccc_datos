
library(dplyr)
library(httr)
library(rvest)
library(purrr)

show_total_n <- function() {
  
  rvest::read_html("https://www.corteconstitucional.gov.co/relatoria/buscador/") |> 
    rvest::html_elements(".row+ .row .text-center") |> 
    rvest::html_text() |> 
    stringr::str_squish() |> 
    cat()
  
}

new_search_engine <- function(keyword, year) {
  
  url <- "https://www.corteconstitucional.gov.co/Relatoria/buscador/SearchDetailt.php"
  
  query <- list(
    searchOption = "texto", 
    fechainicial = paste0(year, "-01-01"), 
    fechafinal = paste0(year, "-12-31"), 
    buscar_por = keyword,
    cant_providencias = "10000"
  )
  
  out <- httr::RETRY("POST", url, body = query, encode = "multipart")
  
  website <- out |> 
    httr::content()  
  
  df <- website |> 
    rvest::html_elements("body") |> 
    rvest::html_table() |> 
    purrr::pluck(1) |> 
    janitor::clean_names() |> 
    dplyr::select(-c(1:2)) |>
    ## removes white spaces
    mutate(providencia = str_replace_all(providencia, "[:space:]", "")) |>
    ## removes any character at the end that's NOT a number
    mutate(providencia = str_remove(providencia, "[^\\d]+$")) |> 
    ## replaces, e.g., C-776/03 with C-776-03
    mutate(providencia = str_replace_all(providencia, "\\.|\\/", "-")) |> 
    mutate(f_sentencia = as.Date(f_sentencia)) |> 
    mutate(year = as.integer(format(f_sentencia, "%Y"))) |> 
    dplyr::mutate(type = stringr::str_extract(providencia, "^(C|SU|T|A)"))
  
  links <- website |> 
    rvest::html_elements("#tablet_results .text-center a:nth-child(1)") |> 
    rvest::html_attr("href") |> 
    stringr::str_replace_all(pattern = "[:space:]", replacement = "")
  
  stopifnot(nrow(df) == length(links))
  
  df$links <- links
  df$path <- stringr::str_remove(links, "https://www.corteconstitucional.gov.co")
  
  return(df)
  
}


