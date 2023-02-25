
library(tidyverse)
library(progress)
library(furrr)
source("helper-functions.R")

out_textos <- "textos/"
out_data <- "data/"

plan(multisession, workers = parallel::detectCores() - 1L)

output <- dir(out_textos, full.names = TRUE) |> 
  furrr::future_map(\(x) str_squish(read_rds(x)))

names(output) <- dir(out_textos) |> str_remove("\\.rds")

# Citations ---------------------------------------------------------------

citations <- future_map(output, extract_cases)
names(citations) <- names(output)

input_el <- citations |>
  enframe(name = "from", value = "to") |>
  unnest(cols = "to")

edge_list <- input_el |>
  mutate(
    from_year = extract_year(from),
    to_year = extract_year(to)
  ) |>
  filter(
    ## this line corrects some typos due (mostly) to problems 
    ## with the documents, NOT the regular expressions
    to_year %in% 1992:2023
  ) |> 
  filter(from != to) |>            ## remove self-citation
  filter(to %in% names(citations)) 

cat("weighted network:", scales::comma(nrow(edge_list)))
cat("unweighted network:", scales::comma(nrow(distinct(edge_list))))

# add relevant metadata ---------------------------------------------------

metadata <- read_rds(str_glue("{out_data}metadata.rds")) |> 
  select(id, date) |> 
  drop_na()

edge_list <- edge_list |> 
  left_join(metadata, by = c("from" = "id")) |> 
  rename(from_date = date) |> 
  left_join(metadata, by = c("to" = "id")) |> 
  rename(to_date = date) 


# export ------------------------------------------------------------------


edge_list <- edge_list |> 
  count(from, to, from_year, to_year, from_date, to_date, name = "weight")

write_rds(edge_list, str_glue("{out_data}citations.rds"), compress = "gz")





# comparing different citation extractions --------------------------------

# set.seed(12345)
# index <- sample(length(output), 100)
# 
# old <- output[index] |> 
#   map(ccc::ccc_sentencias_citadas) |> 
#   enframe(value = "old") |> 
#   mutate(n_old = map_dbl(old, length))
# 
# new <- output[index] |> 
#   map(extract_cases) |> 
#   enframe(value = "new") |> 
#   mutate(n_new = map_dbl(new, length))
# 
# df <- full_join(old, new) |> 
#   arrange(desc(abs(n_old - n_new)))
# df
# 
# setdiff(df$new[[1]], df$old[[1]])
# 
# texto <- output["T-277-09"]
# 
# setdiff(extract_cases2(texto), extract_cases(texto))
