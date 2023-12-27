library(tidyverse)
library(xlsx)
library(matrixStats)
library(DescTools)
library(irrNA)

get_df <- function(tablename, sheetname, daghestanian=F) {
  df <- xlsx::read.xlsx(tablename, sheetName = sheetname)
  if (daghestanian) {
    df %>% 
      filter(lang == "russian") -> df
  } else {
    df %>% 
      filter(lang != "russian") -> df
  }
  
  df <- df[, 6:length(df)]
  
  return(df)
}

get_ranking <- function(df) {
  apply(
    apply(
      df, 1, function(x) {rank(x, na.last = "keep")}
      ), 2, function(x) {
        (x - min(x, na.rm = T)) / (max(x, na.rm = T) - min(x, na.rm = T))
        }
    ) -> x
  
  avg_ranks <- rowMedians(x, na.rm = T)
  
  data.frame(concept = rownames(x), rank = avg_ranks) %>% 
    arrange(rank) %>% 
    filter(!str_detect(concept, "NA")) -> data
  
  return(data)
}


get_alternative_ranking <- function(df) {
  x <- apply(df, 1, function(x) {x / (length(na.omit(x)) + 1)})
  avg_ranks <- rowMedians(x, na.rm = T)
  
  data.frame(concept = rownames(x), rank = avg_ranks) %>% 
    arrange(rank) %>% 
    filter(!str_detect(concept, "NA")) -> data
  
  return(data)
}

write_ranking <- function(tablename, ...) {
  for (name in list(...)) {
    df <- eval(parse(text = name))
    data <- get_ranking(df)
    data %>% 
      xlsx::write.xlsx(tablename, sheetName = name, append=T, row.names = F)
  }
}

write_alternative_ranking <- function(tablename, ...) {
  for (name in list(...)) {
    df <- eval(parse(text = name))
    data <- get_alternative_ranking(df)
    data %>% 
      xlsx::write.xlsx(tablename, sheetName = name, append=T, row.names = F)
  }
}

get_kendallW <- function(...) {
  for (name in list(...)) {
    df <- eval(parse(text = name))
    w <- kendallNA(data.frame(t(df)))$`Kendall's W`
    print(paste(name, round(w, 2)))
  }
}

animals <- get_df("card_sorting_data.xlsx", "animals")
birds <- get_df("card_sorting_data.xlsx", "birds")
utensils <- get_df("card_sorting_data.xlsx", "tools")
bodyparts <- get_df("card_sorting_data.xlsx", "bodyparts")

write_ranking("ranking.xlsx", "animals", "birds", "utensils", "bodyparts")
write_alternative_ranking("ranking_alternative.xlsx",
                          "animals", "birds", "utensils", "bodyparts")
get_kendallW("animals", "birds", "utensils", "bodyparts")



animals_dag <- get_df("card_sorting_data.xlsx", "animals", TRUE)
birds_dag <- get_df("card_sorting_data.xlsx", "birds", TRUE)
utensils_dag <- get_df("card_sorting_data.xlsx", "tools", TRUE)
bodyparts_dag <- get_df("card_sorting_data.xlsx", "bodyparts", TRUE)

write_ranking("ranking_dag.xlsx", "animals_dag", "birds_dag",
              "utensils_dag", "bodyparts_dag")

get_kendallW("animals_dag", "birds_dag", "utensils_dag", "bodyparts_dag")


kendallNA(data.frame(t(birds)))$`Kendall's W`


count_kendall <- function(df) {
  cor.test(get_ranking(df)$rank,
           get_alternative_ranking(df)$rank,
           method="kendall") -> x
  print(x$estimate)
}

count_kendall(animals)
count_kendall(birds)
count_kendall(utensils)
count_kendall(bodyparts)

data <- data.frame()

for (category in c("animals", "birds", "utensils", "bodyparts")) {
  df <- eval(parse(text = category))
  
  ranking <- get_ranking(df)
  
  apply(
    apply(
      df, 1, function(x) {rank(x, na.last = "keep")}
    ), 2, function(x) {
      (x - min(x, na.rm = T)) / (max(x, na.rm = T) - min(x, na.rm = T))
    }
  ) -> df
  
  df_dag <- eval(parse(text = paste(category, "_dag", sep="")))
  apply(
    apply(
      df_dag, 1, function(x) {rank(x, na.last = "keep")}
    ), 2, function(x) {
      (x - min(x, na.rm = T)) / (max(x, na.rm = T) - min(x, na.rm = T))
    }
  ) -> df_dag
  
  merge(df_dag, ranking, by=0, all.y = T) %>% 
    select(starts_with(c("V", "rank"))) -> test
  
  coefs_dag <- c()
  
  for (name in colnames(test)) {
    if (substr(name, 1, 1) == "V") {
      if (length(na.omit(test[[name]])) > 4) {
        coef <- cor.test(test[[name]], test$rank, method="kendall")$estimate[[1]]
        coefs_dag <- append(coefs_dag, coef)
      }
    }
  }
  
  merge(df, ranking, by=0, all.y = T) %>% 
    select(starts_with(c("V", "rank"))) -> test
  
  coefs_rus <- c()
  
  for (name in colnames(test)) {
    if (substr(name, 1, 1) == "V") {
      if (length(na.omit(test[[name]])) > 4) {
        coef <- cor.test(test[[name]], test$rank, method="kendall")$estimate[[1]]
        coefs_rus <- append(coefs_rus, coef)
      }
    }
  }
  
  data <- rbind(data,
                data.frame(cor = coefs_rus, dataset = "rus", category = category),
                data.frame(cor = coefs_dag, dataset = "dag", category = category))
}


ggplot(data, aes(y = cor, color=dataset))+
  geom_boxplot()+
  ylim(c(0.5, 1))+
  ylab("Kendall's τ")+
  theme(axis.title.x=element_blank(),
        axis.text.x=element_blank(),
        axis.ticks.x=element_blank())+
  facet_wrap(~category)



