
library(dplyr)
library(httr)
library(rvest)
library(purrr)

show_total_n <- function() {
  
  rvest::read_html("https://www.corteconstitucional.gov.co/relatoria/buscador_new/") |> 
    rvest::html_elements(".col-lg-11 strong") |> 
    rvest::html_text() |> 
    stringr::str_squish() |> 
    cat()
  
}

## This is now defunct

# new_search_engine <- function(keyword, year) {
#   
#   url <- "https://www.corteconstitucional.gov.co/Relatoria/buscador/SearchDetailt.php"
#   
#   query <- list(
#     searchOption = "texto", 
#     fechainicial = paste0(year, "-01-01"), 
#     fechafinal = paste0(year, "-12-31"), 
#     buscar_por = keyword,
#     cant_providencias = "10000"
#   )
#   
#   out <- httr::RETRY("POST", url, body = query, encode = "multipart")
#   
#   website <- out |> 
#     httr::content()  
#   
#   df <- website |> 
#     rvest::html_elements("body") |> 
#     rvest::html_table() |> 
#     purrr::pluck(1) |> 
#     janitor::clean_names() |> 
#     dplyr::select(-c(1:2)) |>
#     ## removes white spaces
#     mutate(providencia = str_replace_all(providencia, "[:space:]", "")) |>
#     ## removes any character at the end that's NOT a number
#     mutate(providencia = str_remove(providencia, "[^\\d]+$")) |> 
#     ## replaces, e.g., C-776/03 with C-776-03
#     mutate(providencia = str_replace_all(providencia, "\\.|\\/", "-")) |> 
#     mutate(f_sentencia = as.Date(f_sentencia)) |> 
#     mutate(year = as.integer(format(f_sentencia, "%Y"))) |> 
#     dplyr::mutate(type = stringr::str_extract(providencia, "^(C|SU|T|A)"))
#   
#   links <- website |> 
#     rvest::html_elements("#tablet_results .text-center a:nth-child(1)") |> 
#     rvest::html_attr("href") |> 
#     stringr::str_replace_all(pattern = "[:space:]", replacement = "")
#   
#   stopifnot(nrow(df) == length(links))
#   
#   df$links <- links
#   df$path <- stringr::str_remove(links, "https://www.corteconstitucional.gov.co")
#   
#   return(df)
#   
# }


new_search_engine <- function(keyword, year) {
  
  url <- "https://www.corteconstitucional.gov.co/relatoria/buscador_new/index.php"
  
  query <- list(
    searchOption = "texto", 
    fechainicial = paste0(year, "-01-01"), 
    fechafinal = paste0(year, "-12-31"), 
    buscar_por = keyword,
    accion = "search",
    OrderbyOption = "des__score",
    cant_providencias = "10000",
    accion = "generar_excel"
  )
  
  query <- paste(paste(names(query), query, sep = "="), collapse = "&")
  #out <- httr::RETRY("GET", url, body = query)
  
  website <- rvest::session(paste(url, query, sep = "?"))
  stopifnot(httr::status_code(website) == 200)
  
  out <- website |> 
    rvest::html_form() |> 
    purrr::pluck(1) |> 
    rvest::html_form_submit(submit = "bto_show_expedientes")
  
  stopifnot(httr::status_code(out) == 200)
  
  links <- read_html(out) |> 
    html_elements("a") |> 
    html_attr("href")
  
  df <- out |> 
    rvest::read_html() |> 
    rvest::html_table() |>
    purrr::pluck(1) |> 
    janitor::clean_names() |>
    dplyr::select(-c(1:2)) |> 
    ## removes white spaces
    dplyr::mutate(providencia = stringr::str_replace_all(providencia, "[:space:]", "")) |> 
    ## removes any character at the end that's NOT a number
    dplyr::mutate(providencia = stringr::str_remove(providencia, "[^\\d]+$")) |> 
    ## replaces, e.g., C-776/03 with C-776-03
    dplyr::mutate(providencia = stringr::str_replace_all(providencia, "\\.|\\/", "-")) |> 
    dplyr::mutate(f_sentencia = as.Date(f_sentencia)) |> 
    dplyr::mutate(year = as.integer(format(f_sentencia, "%Y"))) |> 
    dplyr::mutate(type = stringr::str_extract(providencia, "^(C|SU|T|A)"))
  
  stopifnot(nrow(df) == length(links))
  
  df$links <- links
  df$path <- stringr::str_remove(links, "https://www.corteconstitucional.gov.co")
  
  return(df)
  
}


