
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

# Checked on 2021-11-23: 36,537 cases

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

# HTML scraper ------------------------------------------------------------

seeds <- read_rds(str_glue("{out_data}seeds.rds")) |> 
  filter(type %in% c("C", "T", "SU")) |> 
  mutate(sentencia = str_replace(sentencia, "SU|su|Su", "SU-"))

seeds2 <- read_rds(str_glue("{out_data}seeds2.rds")) |> 
  filter(type %in% c("C", "T", "SU")) |> 
  mutate(providencia = str_replace(providencia, "SU|su|Su", "SU")) |> 
  rename(sentencia = providencia)

extra_cases <- setdiff(union(seeds2$sentencia, seeds$sentencia), intersect(seeds2$sentencia, seeds$sentencia))

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
  filter(sentencia != "C-289-16")

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

# case "T-680-07" is weirdly not available
str_glue("{out_textos}{names(output[error_index])}.rds") |> file.remove()


output <- dir(out_textos, full.names = TRUE) |> 
  furrr::future_map(\(x) str_squish(read_rds(x)))

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

# Citations ---------------------------------------------------------------

## TO DO, RE-WRITE CCC_SENTENCIAS_CITADAS AND LOOK FOR EDGE CASES
## Move this to new script

## Everything below this point needs to be re-done!!

citations <- future_map(output, ccc::ccc_sentencias_citadas)
names(citations) <- names(output)

input_el <- citations |>
  enframe(name = "from", value = "to") |>
  unnest(cols = "to") |>
  distinct()  ## this removes citation intensity per case!!!

## Find citations from outside the network. This chunk creates the
## missing_ids.rds file which is used to figure out errors in the ccc_sentencias_citadas function.

# outside_ids <- input_el |>
#   mutate(
#     from_year = ccc:::extract_year(from),
#     to_year = ccc:::extract_year(to)
#   ) |>
#   filter(
#     to_year %in% 1992:2021,     ## this line corrects errors (e.g., typos)
#     from_year %in% 1992:2021    ## this line is unnecessary
#   ) |>
#   filter(to_year <= from_year) |>  ## remove blatant errors
#   filter(from != to) |>            ## remove self-citation
#   distinct(to) |> 
#   filter(!to %in% names(output)) |> 
#   pull(to)
# 
# write_rds(outside_ids, str_glue("{out_data}missing_ids.rds"), compress = "gz")

edge_list <- input_el |>
  mutate(
    from_year = ccc:::extract_year(from),
    to_year = ccc:::extract_year(to)
  ) |>
  filter(
    to_year %in% 1992:2021,     ## this line corrects errors (e.g., typos)
    from_year %in% 1992:2021    ## this line is unnecessary
  ) |>
  mutate(
    from_type = str_extract(from, "^(C|SU|T|A)"),
    to_type = str_extract(to, "^(C|SU|T|A)")
  ) |> 
  filter(to_year <= from_year) |>  ## remove blatant errors
  filter(from != to) |>            ## remove self-citation
  filter(to %in% names(output))    ## remove citations from outside the network

nrow(edge_list) |> scales::comma()
 
# # edge_list <- edge_list |> 
# #   filter(to %in% ids) |>
# #   filter(to_year <= from_year) |> 
# #   filter(from != to)  ## remove self-citation



# Old vs New --------------------------------------------------------

## new output

# output <- future_map(dir(out_textos, full.names = TRUE), \(x) str_squish(read_rds(x)))
# names(output) <- dir(out_textos) |> str_remove("\\.rds")
# 
# citations <- future_map(output, ccc::ccc_sentencias_citadas)
# names(citations) <- names(output)
# 
# edge_list <- citations |> 
#   enframe(name = "from", value = "to") |> 
#   unnest(cols = "to") |> 
#   distinct()  ## this removes citation intensity per case!!!
# 

# old_files <- dir("/Users/acastroaraujo/Documents/Repositories/ccc_analisis/textos") |>
#   str_remove("\\.rds")

# new_files <- dir(out_textos) |> str_remove("\\.rds")
# 
# setdiff(old_files, new_files)
# 
# ### old output

# # 
# df_nchar <- enframe(output, "id", "text") |>
#   mutate(nchar = nchar(text)) |>
#   select(!text)
# 
# glimpse(df_nchar)

# 
old_output <- future_map(
  dir("/Users/acastroaraujo/Documents/Repositories/ccc_analisis/textos", full.names = TRUE),
  \(x) str_squish(read_rds(x))
)

names(old_output) <- dir("/Users/acastroaraujo/Documents/Repositories/ccc_analisis/textos") |> str_remove("\\.rds")
# 
# old_df_nchar <- enframe(old_output, "id", "text") |>
#   mutate(old_nchar = nchar(text)) |>
#   select(!text)
# 
# df <- full_join(df_nchar, old_df_nchar) |>
#   mutate(diff = (nchar / old_nchar) - 1) |>
#   filter(id %in% names(output)) 
 
# # output[["C-112-19"]] |> str_view("")
# 


# 
# edge_list <- edge_list |> 
#   mutate(
#     from_year = ccc:::extract_year(from),
#     to_year = ccc:::extract_year(to)
#   ) |> 
#   filter(
#     to_year %in% 1992:2020,     ## stuff here is due to typos and edge cases with regexs
#     from_year %in% 1992:2020    ## this line is unnecessary
#   ) |> 
#   mutate(
#     from_type = str_extract(from, "^(C|SU|T|A)"),
#     to_type = str_extract(to, "^(C|SU|T|A)")
#   )
# 
# # edge_list <- edge_list |> 
# #   filter(to %in% ids) |>
# #   filter(to_year <= from_year) |> 
# #   filter(from != to)  ## remove self-citation
# 
# 
