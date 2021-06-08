library(MASS)
source("util.R")

# Generate folder structure for Model 1 simulation study
# - Make directories for each combination of simulation settings
# - Copy any necessary R files into each
# - Generate launch scripts and scheduler spec files for each
#
# The jobs can also be managed by an outside "job runner" script that
# stays running in the scheduler as long as possible and finds  new
# jobs to process until the simulation is complete.

# ---- Begin config -----
# Levels of the simulation (will be crossed)
sigma_levels = c(1, 2, 3)
n_levels = c(50, 100, 200)

beta_true = c(-1, 1)

N_sim = 200
mcmc_reps = 2000
mcmc_burn = 1000
mcmc_thin = 1
report_period = 500
# ---- End config -----

# A few helper functions
fprintf = function(file, msg, ...) { cat(sprintf(msg, ...), file = file) }
print_vector = function(x) { sprintf("c(%s)", paste(x, collapse = ",")) }

# Generate X matrix to be used throughout simulations
for (idx_n in 1:length(n_levels)) {
	n = n_levels[idx_n]
	X = matrix(rnorm(2*n), n, 2)
	saveRDS(X, file = sprintf("xmat-n%d.rds", n))
}

for (idx_sigma in seq_along(sigma_levels)) {
for (idx_n in seq_along(n_levels)) {
	sigma = sigma_levels[idx_sigma]
	n = n_levels[idx_n]

	# Create run directory
	dd = sprintf("sigma%d_n%d", idx_sigma, idx_n)

	if (dir.exists(dd)) { next }
	dir.create(dd)

	# Write launch.R file
	ff = file(sprintf("%s/launch.R", dd), "w")
	fprintf(ff, "set.seed(1234)\n\n")
	fprintf(ff, "beta_true = %s\n", print_vector(beta_true))
	fprintf(ff, "sigma_true = %f\n", sigma)
	fprintf(ff, "xmat_file = \"%s\"\n", sprintf("../xmat-n%d.rds", n))
	fprintf(ff, "N_sim = %d\n", N_sim)
	fprintf(ff, "mcmc_reps = %d\n", mcmc_reps)
	fprintf(ff, "mcmc_burn = %d\n", mcmc_burn)
	fprintf(ff, "mcmc_thin = %d\n", mcmc_thin)
	fprintf(ff, "report_period = %d\n\n", report_period)
	fprintf(ff, "source(\"%s\")\n", "../sim.R")
	fprintf(ff, "save.image(\"results.Rdata\")\n")
	close(ff)
}
}

