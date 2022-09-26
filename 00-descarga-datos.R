
library(tidyverse)
library(progress)
library(furrr)
source("helper-functions.R")
source("helper-new-searcher.R")

out_textos <- "textos/"
out_data <- "data/"

if (!dir.exists(out_textos)) dir.create(out_textos)
if (!dir.exists(out_data)) dir.create(out_data)

# Seeds -------------------------------------------------------------------

# Checked on 2022-04-30: 37,477 cases

# df <- map_df(0:360, ~ {
#   Sys.sleep(runif(1))
#   ccc::ccc_palabra_clave(q = "corte", p = .x)
# }) |>
#   distinct() |>
#   filter(str_detect(path, "\\.html?$")) |> 
#   mutate(sentencia = toupper(sentencia))
# 
# write_rds(drop_na(df), str_glue("{out_data}seeds.rds"), compress = "gz")

## The following chunk uses the new search enging.
## Type show_total_n() in the console to show the number of cases

# df <- map_df(1992:2021, function(year) {
# 
#   message("Year: ", year)
#   out <- new_search_engine("corte", year)
#   Sys.sleep(runif(1, max = 5))
# 
#   return(out)
# 
# })

# df <- df |>
#   distinct() |>
#   filter(str_detect(path, "\\.html?$")) |> 
#   ## fix weird errors in the path
#   mutate(path = str_replace_all(path, "(.*-)(\\d{2})([^\\d]+)(\\.html?)$", "\\1\\2\\4")) 
# 
# df <- df |> 
#   #fix one really weird error
#   mutate(providencia = ifelse(
#     test = str_detect(providencia, "T-248-154"), 
#     yes = "T-248-15", 
#     no = providencia)
#     ) |>
#   mutate(path = ifelse(
#     test = str_detect(path, "/Relatoria/2015/T-248-154.htm"), 
#     yes = "/Relatoria/2015/T-248-15.htm", 
#     no = path)
#   )
# 
# write_rds(df, str_glue("{out_data}seeds2.rds"), compress = "gz")


## this chunk used the new new engine, added on: 2022-05-02
df <- map_df(2020:2022, function(year) {

  message("Year: ", year)
  out <- new_search_engine("corte", year)
  Sys.sleep(runif(1, max = 5))

  return(out)

})

df <- df |>
  distinct() |>
  filter(str_detect(path, "\\.html?$")) |> 
  ## fix weird errors in the path
  mutate(path = str_replace_all(path, "(.*-)(\\d{2})([^\\d]+)(\\.html?)$", "\\1\\2\\4")) 
# 
write_rds(df, str_glue("{out_data}seeds3.rds"), compress = "gz")


# HTML scraper ------------------------------------------------------------

seeds <- read_rds(str_glue("{out_data}seeds.rds")) |> 
  filter(type %in% c("C", "T", "SU")) |> 
  mutate(sentencia = str_replace(sentencia, "SU|su|Su", "SU-"))

seeds2 <- read_rds(str_glue("{out_data}seeds2.rds")) |> 
  filter(type %in% c("C", "T", "SU")) |> 
  mutate(providencia = str_replace(providencia, "SU|su|Su", "SU")) |> 
  rename(sentencia = providencia)

seeds3 <- read_rds(str_glue("{out_data}seeds3.rds")) |> 
  filter(type %in% c("C", "T", "SU")) |> 
  mutate(providencia = str_replace(providencia, "SU|su|Su", "SU")) |> 
  rename(sentencia = providencia)

extra_cases <- setdiff(union(seeds3$sentencia, seeds2$sentencia), intersect(seeds3$sentencia, seeds2$sentencia))

## There was a weird missing data issue for T cases in 2003
extra_cases |> extract_year() |> table()


full_seeds <- full_join(
  seeds |> select(sentencia, path),
  seeds2 |> select(sentencia, path)
  ) |> distinct() |> 
  ## Remove duplicate
  ## https://www.corteconstitucional.gov.co/Relatoria/2000/T-1580-00.htm
  ## https://www.corteconstitucional.gov.co/Relatoria/2000/T-1580-01.htm
  filter(sentencia != "T-1580-01") |> 
  ## Remove duplicate
  ## https://www.corteconstitucional.gov.co/Relatoria/2017/C-289-17.htm
  ## https://www.corteconstitucional.gov.co/Relatoria/2016/C-289-16.htm
  filter(sentencia != "C-289-16") |> 
  full_join(seeds3 |> select(sentencia, path))

dict <- full_seeds |> select(sentencia, path) |> deframe()
sentencias_done <- str_replace(dir(out_textos), ".rds", "")
sentencias_left <- setdiff(full_seeds$sentencia, sentencias_done)

pb <- progress_bar$new(format = "[:bar] :current/:total (:percent)\n", total = length(sentencias_left))

while (length(sentencias_left) > 0) { 
  
  x <- sample(sentencias_left, 1)
  texto <- try(scraper_html(dict[[x]]))
  
  write_rds(texto, str_glue("{out_textos}{x}.rds"), compress = "gz")
  sentencias_left <- sentencias_left[-which(sentencias_left %in% x)] ## int. subset
  
  pb$tick()
  Sys.sleep(runif(1, 0, 2))
  
}

plan(multisession, workers = parallel::detectCores() - 1L)

output <- dir(out_textos, full.names = TRUE) |> 
  furrr::future_map(\(x) read_rds(x))

names(output) <- dir(out_textos) |> str_remove("\\.rds")

error_index <- output |> 
  map_lgl(\(x) any(class(x) == "try-error")) |> 
  which()

length(error_index)
names(output[error_index])

# case "T-680-07", "T-322-20", and "T-104-22" are weirdly not available
str_glue("{out_textos}{names(output[error_index])}.rds") |> file.remove()

output <- dir(out_textos, full.names = TRUE) |> 
  furrr::future_map(\(x) read_rds(x))

names(output) <- dir(out_textos) |> str_remove("\\.rds")

# Check encoding ----------------------------------------------------------

char_index <- future_map_lgl(output, str_detect, pattern = "á|é|í|ó|ú", negate = TRUE)
sum(char_index)

# sentencias_left <- names(char_index)[char_index]
# pb <- progress_bar$new(format = "[:bar] :current/:total (:percent)\n", total = length(sentencias_left))
# 
# while (length(sentencias_left) > 0) {
# 
#   x <- sample(sentencias_left, 1)
#   texto <- try(scraper_html(dict[[x]], encoding = ""))
# 
#   write_rds(texto, str_glue("{out_textos}{x}.rds"), compress = "gz")
#   sentencias_left <- sentencias_left[-which(sentencias_left %in% x)] ## int. subset
# 
#   pb$tick()
#   Sys.sleep(runif(1, 0, 2))
# 
# }


# Check for bad quotation marks -------------------------------------------

quotes_index <- future_map_lgl(output, str_detect, pattern = "\\u0093|\\u0094")
sum(quotes_index)

output[quotes_index] <- furrr::future_map(
  output[quotes_index], str_replace_all, 
  pattern = "\\u0093|\\u0094", replacement = '"'
)


for (i in seq_along(output[quotes_index])) {
  
  write_rds(output[quotes_index][[i]], str_glue("{out_textos}{names(output[quotes_index][i])}.rds"), compress = "gz")
  
}


# Check for other bad stuff -----------------------------------------------

other_index <- future_map_lgl(output, str_detect, pattern = "\\u0096|\\u0097|\\u0092|\u0091")
sum(other_index)

output[other_index] <- furrr::future_map(
  output[other_index], function(text) {
    text |> 
      str_replace_all(pattern = "\\u0092|\\u0091", replacement = "'") |> 
      str_replace_all(pattern = "\\u0096|\\u0097", replacement = "-")
  }
)

for (i in seq_along(output[other_index])) {
  
  write_rds(output[other_index][[i]], str_glue("{out_textos}{names(output[other_index][i])}.rds"), compress = "gz")
  
}



