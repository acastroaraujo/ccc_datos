
# scraper_texto <- function(path) {
#   
#   if (!stringr::str_detect(path, pattern = "\\.htm")) stop(call. = FALSE, "la dir. debe terminar en .htm")
#   
#   website <- httr::RETRY("GET", paste0("https://www.corteconstitucional.gov.co", path)) |> 
#     xml2::read_html(encoding = "latin1")
#   
#   url <- website |> 
#     rvest::html_elements("a") |> 
#     purrr::pluck(1) |> 
#     rvest::html_attr("href") |> 
#     stringr::str_squish()
#   
#   message("Descargando: ", url)
#   
#   if (!stringr::str_detect(url, pattern = "\\.rtf")) stop(call. = FALSE, "la dir. debe terminar en .rtf")
#   
#   temp_path <- paste0(tempdir(), "temp_file.rtf")
#   download.file(paste0("https://www.corteconstitucional.gov.co", url), temp_path, quiet = TRUE)
#   out <- suppressMessages(striprtf::read_rtf(temp_path, check_file = TRUE, encoding = "latin1"))
#   
#   if (is.null(out)) stop(call. = FALSE, paste0(url, " does not seem to be an RTF file"))
#   
#   return(paste(out, collapse = "\n"))
#   
# }

# path <- dict[["T-067-20"]]
# path <- dict[["T-376-20"]]
# path <- dict[["T-892-08"]]

scraper_html <- function(path, encoding = "latin1") {
  
  if (!stringr::str_detect(path, pattern = "\\.htm")) stop(call. = FALSE, "la dir. debe terminar en .htm")
  message("Descargando: ", path)
  
  website <- httr::RETRY("GET", paste0("https://www.corteconstitucional.gov.co", path)) |>
    xml2::read_html(encoding = encoding)
  
  selector <- ".amplia div"
  
  out <- website |> 
    rvest::html_elements(selector) |> 
    rvest::html_text() 
  
  if (purrr::is_empty(out)) {
    
    selector <- "div"
    
    out <- website |> 
      rvest::html_elements(selector) |> 
      rvest::html_text()
    
  } 
    
  keep <- website |>                        ## this chunk
    rvest::html_elements(selector) |>  ## indexes all
    rvest::html_attrs()  |>                 ## redundant
    purrr::map(\(x) names(x)) |>            ## footnotes
    purrr::map_lgl(\(x) {
      if (purrr::is_empty(x)) TRUE else !stringr::str_detect(x[[1]], "id")
    }) 
  
  return(paste(out[keep], collapse = ""))
    
}


extract_year <- function(x) {
  
  stringr::str_extract(x, "\\d{2}$") |>
    as.Date("%y") |> 
    format("%Y") |>  
    as.integer()
  
}

extract_full_date <- function(sentencia, texto) {
  
  y <- extract_year(sentencia)
  
  ## Find the sentence that contains the full date
  regex_ep <- paste0(
    r"{Bogot(a|á) ?,? ?(D\.? ?C? ?\.?\.?,?)?[^\.]+\(? ?}",
    str_replace(y, "(\\d)(\\d{3})", "\\1\\.?\\2"), 
    r"{ ?\)?\.?}")
  
  input <- texto |> 
    stringr::str_extract(regex_ep)
  
  if (is.na(input)) {
    
    input <- str_sub(texto, 1, 200) |> 
      str_extract("\\(.+\\)")
    
  }
  
  if (is.na(input)) stop("La fecha de este texto tiene un formato atípico.", call. = FALSE)
  
  if (stringr::str_detect(input, "acta")) {
    
    d <- input |> 
      stringr::str_extract_all("\\d{1,2}") |> 
      unlist() |> 
      pluck(2)
    
  } else {
    
    d <- input |> 
      stringr::str_extract("\\d{1,2}")
    
  }
  
  month_lookup <- c(
    "enero" = "01", 
    "febrero" = "02", 
    "marzo" = "03", 
    "abril" = "04", 
    "mayo" = "05", 
    "junio" = "06", 
    "julio" = "07", 
    "agosto" = "08", 
    "septiembre" = "09", 
    "octubre" = "10", 
    "noviembre" = "11", 
    "diciembre" = "12"
  )
  
  m <- input |> 
    stringr::str_to_lower() |> 
    stringr::str_extract("enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre") |> 
    stringr::str_replace_all(month_lookup)
  
  if (any(is.na(c(y, m, d)))) return(NA)
  
  as.Date(paste(y, m, d, sep = "-"))
  
}


theme_custom <- function(base_family = "Avenir Next Condensed", fill = "white", ...) {
  theme_minimal(base_family = base_family, ...) %+replace%
    theme(
      plot.title = element_text(face = "bold", margin = margin(0, 0, 5, 0), hjust = 0, size = 13),
      plot.subtitle = element_text(face = "italic", margin = margin(0, 0, 5, 0), hjust = 0),
      plot.background = element_rect(fill = fill, size = 0), complete = TRUE,
      axis.title.x = element_text(margin = margin(15, 0, 0, 0)),
      axis.title.y = element_text(angle = 90, margin = margin(0, 20, 0, 0)),
      strip.text = element_text(face = "bold", colour = "white"),
      strip.background = element_rect(fill = "#4C4C4C")
    )
}


