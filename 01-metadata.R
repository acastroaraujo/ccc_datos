
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
  rename(sentencia = providencia)

df1 <- seeds2 |> 
  select(c("id" = "sentencia", "date" = "f_sentencia"), everything())

# Fechas ------------------------------------------------------------------

cases <- str_replace(dir(out_textos), ".rds", "")
cases <- setdiff(cases, df1$id)
pb <- progress_bar$new(format = "[:bar] :current/:total (:percent)", total = length(cases))

output <- map(cases, function(x) {
  
  texto <- str_squish(read_rds(paste0(out_textos, x, ".rds")))
  out <- try(extract_full_date(x, texto))
  names(out) <- x
  return(out)
  
})

names(output) <- cases

error_index <- output %>% 
  map_lgl(~ any(class(.x) == "try-error")) %>% 
  which()

length(output[error_index])

names(output[error_index])

#### Manual coding 

output[["T-277-09"]] <- NA # https://www.corteconstitucional.gov.co/relatoria/2009/T-277-09.htm

# Export ------------------------------------------------------------------

df2 <- enframe(output, name = "id", value = "date") |> 
  unnest(cols = "date") |> 
  mutate(year = lubridate::year(date)) |> 
  mutate(across(everything(), unname)) |> 
  mutate(type = str_extract(id, "^(C|SU|T|A)")) 

df <- full_join(df1, df2)

## Finish cleaning

tipo_lookup <- c("T" = "Tutela", "SU" = "Sentencia de unificación", "C" = "Constitucionalidad")

separate_names <- function(x) {
  x |> 
    str_remove_all("\\([A-Za-z ]+\\)") |> 
    str_replace_all("([:lower:])([:upper:])", "\\1_\\2") |> 
    str_split("_") 
}

metadata <- df |> 
  ## fix this one weird typo
  mutate(ponentes = ifelse(
    test = ponentes == "Esteban Restrepo Saldarriaga (Conju",
    yes = "Esteban Restrepo Saldarriaga",
    no = ponentes
  )) |>
  ## fix missing years
  mutate(year = ifelse(is.na(year), extract_year(id), year)) |> 
  mutate(year = as.integer(year)) |> 
  ## add missing spanish type
  mutate(tipo = tipo_lookup[type]) |>
  select(id, type, year, date, tipo, resumen, ponentes, salvamentos_y_aclaraciones_de_voto) |> 
  ## clarify NAs
  mutate(across(where(is.character), \(x) ifelse(x == "Sin Información", NA_character_, x))) |> 
  mutate(
    ponentes = separate_names(ponentes),
    salvamentos_y_aclaraciones_de_voto = separate_names(salvamentos_y_aclaraciones_de_voto)
  ) |> 
  arrange(date) |>                      ## In case of duplicates, this keeps the one with the
  distinct(id, type, .keep_all = TRUE)  ## earliest date. A handful of cases were uploaded to the
                                        ## database twice on different dates.   

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



