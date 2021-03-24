library(rio)
library(MASS)
library(stringr)

source("write_input_files.R")

R <- 10

input.species <- import("input data/Data used for gsmax vs CO2 regression and iWUE vs CO2 regression.xlsx", which = "Gsmax vs CO2")
input.species$gsmax <- input.species$`Gmax mol  m-2 s-1` / .04 / 1000 # convert from mol/m2s to m/s

# Amaroria 0.145, Astronidium 0.08, Dillenia 0.13, Elatostachys 0.035 and Gnetum 0.03
rubisco.values <- c(
  "Amaroria soulameoides" = .145,
  "Astronidium confertiflorum" = .08,
  "Dillenia biflora" = .13,
  "Gnetum gnemon" = .03,
  "Elattostachys falcata" = .035
)

gsmax.values <- c(
  "Amaroria soulameoides" = 1351,
  "Astronidium confertiflorum" = 1027,
  "Dillenia biflora" = 627,
  "Gnetum gnemon" = 592,
  "Elattostachys falcata" = 1001
) / .04 / 1000


output <- expand.grid(
  replication = 1:R,
  species = unique(input.species$Species),
  iwue_co2_slope = NA,
  mean_iwue = NA,
  gsmax_co2_slope = NA,
  mean_gsmax = NA,
  psnSun_co2_slope = NA,
  mean_psnSun = NA,
  evpGLSSun_co2_slope = NA,
  mean_evpGLSSun = NA,
  evpGLSMax_co2_slope = NA,
  mean_evpGLSMax = NA
)
output$rubisco <- rubisco.values[output$species]
output$gsmax <- gsmax.values[output$species]


for (i in 1:NROW(output)) {

  cat(".")

  speciesName <- str_replace(output$species[i], " ", "_")

  # m <- lm(gsmax ~ `CO2`, input.species, subset = Species == output$species[i])

  # bhat <- mvrnorm(1, coef(m), vcov(m))
  gsmax <- rep(output$gsmax[i], length(input.co2$CO2)) # cbind(1, input.co2$CO2) %*% bhat
  year <- input.co2$Year

  iniFile <- str_replace(readLines("ini/simulations.ini"), "ebf", paste0(speciesName, "_edited"))
  cat(paste0(iniFile, collapse = "\n"), file = "ini/simulations_auto.ini")

  epcFile <- str_replace(readLines(paste0("epc/", speciesName, ".epc")), "0.06", as.character(output$rubisco[i])) # this works, because only one setting has "0.06"
  cat(paste0(epcFile, collapse = "\n"), file = paste0("epc/", speciesName, "_edited.epc"))


  if (output$replication[i] %% 100 == 0) cat(output$replication[i], "...")

  cat("", file = "input/gsmax.txt")
  cat(sprintf("%4.0f %10.8f\n", year, gsmax), file = "input/gsmax.txt", append = TRUE)

  system("./bgc -s ini/simulations_auto.ini")

  annAverages <- as.data.frame(matrix(
    readBin(con <- file("outputs/simulation.annavgout", "rb"), double(), 37 * 3, size = 4),
    nrow = 37, byrow = TRUE))
  close(con)
  names(annAverages) <- c("psnSun",    # 579    22 psn_sun.A     (A)
                          "evpGLSSun", # 539    23 epv.gl_s_sun  (gs)
                          "evpGLSMax") # 547    24 epv.gl_smax
  # annAverages$year <- year

  annAverages$evpGLSMax_orig <- annAverages$evpGLSMax
  annAverages$evpGLSSun_orig <- annAverages$evpGLSSun

  annAverages$evpGLSMax <- annAverages$evpGLSMax * 1000 * .04   # convert from (m s-1) to (mol m-2 s-1)
  annAverages$evpGLSSun <- annAverages$evpGLSSun * 1000 * .04

  annAverages$iwue <- annAverages$psnSun / (annAverages$evpGLSSun)

  annAverages$evpGLSSun <- annAverages$evpGLSSun * 1000         # convert from (mol m-2 s-1) to (mmol m-2 m-1)
  annAverages$evpGLSMax <- annAverages$evpGLSMax * 1000

  if (output$replication[i] == 1) {
    annAverages$year <- year
    annAverages$gsmax_input <- gsmax
    annAverages$co2 <- input.co2$CO2
    export(annAverages, file = paste0("simulation output - ", output$species[i], " - Rubisco N ", as.character(output$rubisco[i]), " - gsmax ", output$gsmax[i], " - replication 1.xlsx"))
    save(list = ls(all.names = TRUE), file = paste0("simulation output - ", output$species[i], " - Rubisco N ", as.character(output$rubisco[i]), " - gsmax ", output$gsmax[i], " - replication 1.Rdata"))
  }

  output$gsmax_co2_slope[i] <- NA # bhat[2]
  output$mean_gsmax[i] <- mean(gsmax)
  output$iwue_co2_slope[i] <- coef(lm(annAverages$iwue ~ input.co2$CO2))[2]
  output$mean_iwue[i] <- mean(annAverages$iwue)
  output$psnSun_co2_slope[i] <- coef(lm(annAverages$psnSun ~ input.co2$CO2))[2]
  output$mean_psnSun[i] <- mean(annAverages$psnSun)
  output$evpGLSSun_co2_slope[i] <- coef(lm(annAverages$evpGLSSun ~ input.co2$CO2))[2]
  output$mean_evpGLSSun[i] <- mean(annAverages$evpGLSSun)
  output$evpGLSMax_co2_slope[i] <- coef(lm(annAverages$evpGLSMax ~ input.co2$CO2))[2]
  output$mean_evpGLSMax[i] <- mean(annAverages$evpGLSMax)
}

save.image("temp.Rdata")

out <- expand.grid(
  variable = names(output)[-c(1:2)],
  quantile = c(0.025, .05, .95, .975),
  species = unique(output$species),
  rubisco = unique(output$rubisco),
  value = NA, stringsAsFactors = FALSE
)
for (i in 1:NROW(out)) {
  out$value[i] <- quantile(output[output$species == out$species[i] & output$rubisco == out$rubisco[i], out$variable[i]], out$quantile[i], na.rm = TRUE)
}
export(out, file = "simulation output - fix gsmax - confidence interval.xlsx")

export(output, file = "simulation output - fix gsmax.xlsx")

if (Sys.getenv("RSTUDIO") != "1") save.image(file = "simulation output - fix gsmax.Rdata")
