library(rio)
library(MASS)
library(stringr)

source("write_input_files.R")

R <- 10000

input.species <- import("input data/Data used for gsmax vs CO2 regression and iWUE vs CO2 regression.xlsx", which = "Gsmax vs CO2")
input.species$gsmax <- input.species$`Gmax mol  m-2 s-1` / .04 / 1000 # convert from mol/m2s to m/s

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

for (species in unique(input.species$Species)) {

  cat("\n", species, ": ")

  speciesName <- str_replace(species, " ", "_")

  m <- lm(gsmax ~ `CO2`, input.species, subset = Species == species)

  bhat <- mvrnorm(R, coef(m), vcov(m))
  gsmax <- cbind(1, input.co2$CO2) %*% t(bhat)
  year <- input.co2$Year

  iniFile <- str_replace(readLines("ini/simulations.ini"), "ebf", speciesName)
  cat(paste0(iniFile, collapse = "\n"), file = "ini/simulations_auto.ini")

  for (i in 1:R) {

    if (i %% 100 == 0) cat(i, "...")

    cat("", file = "input/gsmax.txt")
    cat(sprintf("%4.0f %10.8f\n", year, gsmax[, i]), file = "input/gsmax.txt", append = TRUE)

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

    if (i == 1) {
      annAverages$year <- year
      annAverages$gsmax_input <- gsmax[, i]
      annAverages$co2 <- input.co2$CO2
      export(annAverages, file = paste0("simulation output - full set CI - ", species, " - replication 1.xlsx"))
      save(list = ls(all.names = TRUE), file = paste0("simulation output - full set CI - ", species, " - replication 1.Rdata"))
    }

    output$gsmax_co2_slope[output$replication == i & output$species == species] <- bhat[i, 2]
    output$mean_gsmax[output$replication == i & output$species == species] <- mean(gsmax[, i])
    output$iwue_co2_slope[output$replication == i & output$species == species] <- coef(lm(annAverages$iwue ~ input.co2$CO2))[2]
    output$mean_iwue[output$replication == i & output$species == species] <- mean(annAverages$iwue)
    output$psnSun_co2_slope[output$replication == i & output$species == species] <- coef(lm(annAverages$psnSun ~ input.co2$CO2))[2]
    output$mean_psnSun[output$replication == i & output$species == species] <- mean(annAverages$psnSun)
    output$evpGLSSun_co2_slope[output$replication == i & output$species == species] <- coef(lm(annAverages$evpGLSSun ~ input.co2$CO2))[2]
    output$mean_evpGLSSun[output$replication == i & output$species == species] <- mean(annAverages$evpGLSSun)
    output$evpGLSMax_co2_slope[output$replication == i & output$species == species] <- coef(lm(annAverages$evpGLSMax ~ input.co2$CO2))[2]
    output$mean_evpGLSMax[output$replication == i & output$species == species] <- mean(annAverages$evpGLSMax)
  }
}

out <- unlist(apply(output[, -c(1,2)], 2, function(x) (tapply(x, output$species, quantile, c(0.025, .05, .95, .975)))))
slope <- unlist(lapply(strsplit(names(out), "[.]"), function(x) { x[1] }))
species <- unlist(lapply(strsplit(names(out), "[.]"), function(x) { x[2] }))
quant <- unlist(lapply(strsplit(names(out), "[.]"), function(x) { paste(x[-c(1,2)], collapse = ".") }))
export(data.frame(species = species, slope = slope, quantile = quant, value = unname(out)), file = "simulation output - confidence interval.xlsx")

export(output, file = "simulation output - full set CI.xlsx")

if (Sys.getenv("RSTUDIO") != "1") save.image(file = "simulation output - full set CI.Rdata")
