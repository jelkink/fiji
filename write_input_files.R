library(rio)

# Note that throughout, gsmax is in mm/s, but when writing the input file to BGC, it's converted to m/s

input.mtc43 <- import("input data/MTCLIM-XL_0.4a.xlsx", which = "fiji.mtc43")
input.co2   <- import("input data/MTCLIM-XL_0.4a.xlsx", which = "CO2")

# NOTE: I skip the fiji.ini and fiji.mtcin tabs, since the former seems to be default settings (?) and the latter is included
# in the mtc43 tab, which has the format used in BGC.

# Write meteorological data file in appropriate format
cat("Fiji, 1979-2015
    MTCLIM v4.3 OUTPUT FILE
    year  yday    Tmax    Tmin    Tday    prcp      VPD     srad  daylen
    (deg C) (deg C) (deg C)    (cm)     (Pa)  (W m-2)     (s)
    ", file = "input/mtc43.txt")
apply(input.mtc43, 1, function(x) {
  x <- as.vector(t(x))
  cat(sprintf("  %4.0f  %4.0f %7.2f %7.2f %7.2f %7.2f  %7.2f  %7.2f %7.0f\n", x[1], x[2], x[3], x[4], x[5], x[6], x[7], x[8], x[9]), file = "input/mtc43.txt", append = TRUE)
})

# Write CO2 file in appropriate format
cat("", file = "input/co2.txt")
apply(input.co2, 1, function(x) {
  x <- as.vector(t(x))
  cat(sprintf("%4.0f %10.8f\n", x[1], x[2]), file = "input/co2.txt", append = TRUE)
})
