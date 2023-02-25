
## one day I'll be able to rely entirely on raw_metadata

library(tidyverse)
library(progress)
library(furrr)
library(lubridate)
source("helper-functions.R")

out_textos <- "textos/"
out_data <- "data/"

seeds2 <- read_rds(str_glue("{out_data}seeds2.rds")) %>% 
  filter(type %in% c("C", "T", "SU")) |> 
  mutate(providencia = str_replace(providencia, "SU|su|Su", "SU")) |> 
  select(id = providencia, ponentes, date = f_sentencia, year, type) |> 
  mutate(ponentes = stringi::stri_trans_general(ponentes, "Latin-ASCII")) 

i_2 <- unique(seeds2$id)

raw_metadata <- read_rds(str_glue("{out_data}raw_metadata.rds")) |> 
  filter(type %in% c("C", "T", "SU")) |> 
  select(id = providencia, ponentes = magistrados, date = f_sentencia, year, type) |> 
  mutate(id = str_replace(id, "SU|su|Su", "SU")) |> 
  mutate(ponentes = stringi::stri_trans_general(ponentes, "Latin-ASCII")) 

i_raw <- unique(raw_metadata$id)

setdiff(i_2, i_raw)

seeds2 <- seeds2 |> 
  filter(id %in% setdiff(i_2, i_raw)) |> 
  mutate(ponentes = ifelse(
    test = ponentes == "Gloria Stella Ortiz DelgadoCristina Pardo Schlesinger",
    yes = "Gloria Stella Ortiz Delgado\r\nCristina Pardo Schlesinger",
    no = ponentes
    )
  )

df <- full_join(seeds2, raw_metadata) 


## Finish cleaning

tipo_lookup <- c("T" = "Tutela", "SU" = "Sentencia de unificación", "C" = "Constitucionalidad")

separate_names <- function(x) {
  str_split(tolower(x), "\r\n") 
}

metadata <- df |> 
  ## add missing spanish type
  mutate(tipo = unname(tipo_lookup[type])) |> 
  ## clarify NAs
  mutate(across(where(is.character), \(x) ifelse(x == "Sin Informacion", NA_character_, x))) |> 
  arrange(date) |>                      ## In case of duplicates, this keeps the one with the
  distinct(id, type, .keep_all = TRUE)  ## earliest date. A handful of cases were uploaded to the
                                        ## database twice on different dates.

metadata[metadata$id == "T-015-92", ]$ponentes <- "Fabio Moron Diaz"
metadata[metadata$id == "T-225-92", ]$ponentes <- "Jaime Sanin Greiffenstein"

metadata <- metadata |> 
  mutate(ponentes = tolower(ponentes)) |> 
  mutate(ponentes = str_remove_all(ponentes, "\\(conjuez\\)")) |> 
  mutate(ponentes = str_split(ponentes, "\r\n")) |> 
  mutate(ponentes = map(ponentes, str_squish)) 

glimpse(metadata)

write_rds(metadata, str_glue("{out_data}metadata.rds"), compress = "gz")

# misc --------------------------------------------------------------------

metadata |> 
  unnest(ponentes) |> 
  count(ponentes, sort = TRUE) 

metadata |> 
  select(date) |> 
  drop_na() |> 
  mutate(day = lubridate::day(date),
         wday = lubridate::wday(date, label = TRUE, week_start = 1),
         year = lubridate::year(date)) |>
  count(wday) |>
  ggplot(aes(wday, n)) + 
  geom_col(width = 1/2) + 
  geom_text(aes(label = scales::comma(n), y = n + 250), family = "Crimson Text", size = 3) +
  theme_custom(base_family = "Crimson Text") + 
  scale_y_continuous(labels = scales::comma) + 
  labs(x = "", y = "", title = "Sentencias de la Corte Constitucional", 
       subtitle = "por día de la semana", caption = "tipos: C, T, SU")

ggsave("weekly-cases.png", device = "png", dpi = "print", width = 7, height = 4)



