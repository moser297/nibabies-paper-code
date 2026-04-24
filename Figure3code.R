setwd("/mypath/NibabiesPaper") #directory with data tables
library(tidyverse)
library(NHANES)
library(DescTools)

data <- read.csv( "BCP_summary_within_between_all.csv", header=TRUE, sep=",") 

sum.dat <- data %>%                               # Summary by group using dplyr
  group_by(condition) %>% 
  summarize(mean.m = mean(mean_value),
            mean.SD = mean(sd_value))

ggplot(data, aes(x = network, y = mean_value, color=condition)) +
#ggplot(data, aes(x = fct_reorder(network, mean_value, .desc = TRUE), y = mean_value, color=condition)) +
    geom_point(size = 3) +
  geom_errorbar(aes(ymin = mean_value - sd_value, 
                    ymax = mean_value + sd_value), 
                width = 0.3) +
  scale_color_manual(values = c("Within" = "#06232E", "Between" = "#6490A1"))+
  ylab("mean connectivity") +
  theme_bw() +
  theme(
    strip.text.y = element_text(size = 18),
    text = element_text(size = 18),
    legend.title = element_blank(),
    legend.position = "inside",
    legend.position.inside = c(0.95, 0.95),
    legend.justification = c(0.95, 0.95),
    axis.text.x=element_text(angle = 90, size=16, color="black", vjust=0.5),
    axis.text.y=element_text(size=18, color="black"),
    axis.title.y = element_text(size = 18),
    axis.title.x = element_blank(),
    #panel.border = element_blank(),
    axis.line = element_line(colour = "black")
  )
