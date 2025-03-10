library(dplyr)
library(dd4d)

set.seed(314159)

pop_n <- 1000
index_date <- as.Date("2020-12-08")

pfizer_name <- "COVID-19 mRNA Vaccine Comirnaty 30micrograms/0.3ml dose conc for susp for inj MDV (Pfizer)"
az_name <- "COVID-19 Vaccine Vaxzevria 0.5ml inj multidose vials (AstraZeneca)"


# define each variable as a node in a bayesian network

sim_list <- lst(
  
  registered = bn_node(
    ~ rbernoulli(n = ..n, p = 0.99)
  ),
  age = bn_node(
    ~ as.integer(rnorm(..n, mean= 55, sd=20)),
  ),
  sex = bn_node(
    ~ rfactor(n = ..n, levels = c("female", "male", "intersex", "unknown"), p = c(0.50, 0.49, 0, 0.01)),
    missing_rate = ~0.01 # this is shorthand for ~(rbernoulli(n=..n, p = 0.2))
  ),
  diabetes = bn_node(
    ~ rbernoulli(n = ..n, p = 0.10)
  ),
  vaccine_date1 = bn_node(
    ~ runif(n = ..n, 0, 150),
    missing_rate = ~0.2,
  ),
  vaccine_date2 = bn_node(
    ~ vaccine_date1 + runif(n = ..n, 3*7, 16*7),
    missing_rate = ~0.1,
    needs = "vaccine_date1"
  ),
  vaccine_product1 = bn_node(
    ~ rcat(n = ..n, c(pfizer_name, az_name), c(0.5, 0.5)), 
    needs = "vaccine_date1"
  ),
  vaccine_product2 = bn_node(
    ~ if_else(runif(..n) < 0.95, vaccine_product1, c(az_name)), 
    needs = "vaccine_date2"
  ),
  death_date = bn_node(
    ~ runif(n = ..n,  0, 1000),
    missing_rate = ~0.95
  )
)

bn <- bn_create(sim_list,known_variables = c("pfizer_name","az_name"))

# plot the network
bn_plot(bn)

# plot the network (connected nodes only)
bn_plot(bn, connected_only = TRUE)

# simulate the dataset
dummy_data <- bn_simulate(bn, pop_size = pop_n, keep_all = FALSE, .id = "patient_id")

dummy_data_days_to_dates <- dummy_data %>%
  mutate(across(contains("_date"), ~ index_date + .)) 

# write to arrow file
arrow::write_feather(dummy_data_days_to_dates, sink = here::here("output", "dummy_dataset_2b.arrow"))

