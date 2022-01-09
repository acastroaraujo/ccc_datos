
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

extract_cases <- function(texto) {
  
  mes <- "(enero|febrero|marzo|abril|mayo|junio|julio|agosto|septiembre|octubre|noviembre|diciembre)"
  
  ## This is the most general pattern, it should capture most cases
  regex1 <- paste0("\\b(C|SU|T) ?(-| ) ?(\\d{3,4}A?) ?del?( \\d{1,2} de ", mes, " de)?( ", mes, " \\d{1,2} del?)? \\d\\.?\\d(\\d{2})\\b")
  
  # This pattern is common in the footnotes, but it also captures the name of the document
  # Thus, remember to remove self-citations
  regex2.1 <- "\\b(C|SU|T) ?(-| ) ?(\\d{3,4}A?)\\/(\\d{2})\\b"
  regex2.2 <- "\\b(C|SU|T) ?(-| ) ?(\\d{3,4}A?)\\/\\d{2}(\\d{2})\\b"
  
  ## This pattern tries to capture cases that are expressed in list-like fashion
  regex3 <- "\\b((?:C|SU|T)(?:-| ) ?\\d{3,4}A?(?:, | y ))+[CSUT\\- \\d, ]*de \\d{4}"
  
  out1 <- texto |> 
    stringr::str_extract_all(regex1) |> 
    purrr::flatten_chr() |> 
    stringr::str_replace_all(pattern = regex1, replacement = "\\1-\\3-\\8")
  
  out2.1 <- texto |> 
    stringr::str_extract_all(regex2.1) |> 
    purrr::flatten_chr() |> 
    stringr::str_replace_all(pattern = regex2.1, replacement = "\\1-\\3-\\4")
  
  out2.2 <- texto |> 
    stringr::str_extract_all(regex2.2) |> 
    purrr::flatten_chr() |> 
    stringr::str_replace_all(pattern = regex2.2, replacement = "\\1-\\3-\\4")
  
  out3 <- texto |> 
    stringr::str_extract_all(regex3) |> 
    purrr::flatten_chr() |> 
    purrr::map(function(x) {
      
      suffix <- unlist(stringr::str_extract(x, regex1)) |> 
        stringr::str_extract("\\d{2}$")
      
      output <- x |> 
        stringr::str_extract_all("(C|SU|T) ?(-| ) ?(\\d+)") |> 
        purrr::flatten_chr() |> 
        paste0("-", suffix) |> 
        stringr::str_remove_all("[:space:]")
      
      output[-length(output)]  ## the last case should have already been identified in out1
      
    }) |> purrr::flatten_chr()
    
  c(out1, out2.1, out2.2, out3)
}

extract_descriptors <- function(texto) {
  
  regex <- "\\b[A-ZÁÉÍÓÚÜÑ\"]{2,}[A-ZÁÉÍÓÚÜÑ\", /]+?(?=-[A-Z])"
  
  if (str_detect(texto, "\\bReferencia:|\\bREFERENCIA:")) {
    
    out <- texto |>
      stringr::str_extract(".+?(?=\\bReferencia:|\\bREFERENCIA:)") |> 
      stringr::str_extract_all(regex) |> 
      unlist() |> 
      stringr::str_squish()
    
    return(out)
    
  }
  
  if (str_detect(texto, "\\bExpediente:|\\bEXPEDIENTE:")) {

    out <- texto |>
      stringr::str_extract(".+?(?=\\bExpediente:|\\bEXPEDIENTE:)") |> 
      stringr::str_extract_all(regex) |> 
      unlist() |> 
      stringr::str_squish()
    
    return(out)
    
  }
  
  if (str_detect(texto, "Ref\\.?:|REF\\.?:")) {
    
    out <- texto |>
      stringr::str_extract(".+?(?=\\bRef\\.?:|\\bREF\\.?:)") |> 
      stringr::str_extract_all(regex) |> 
      unlist() |> 
      stringr::str_squish()
    
    return(out)
    
  }
  
  return(NULL)
  
}

