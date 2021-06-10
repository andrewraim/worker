source("util.R")

# ---- Begin config -----
# Levels of sigma and n will be crossed
N_sim = 200
beta_true = c(-1, 1)
sigma_levels = c(1, 2, 3)
n_levels = c(50, 100, 200)
# ---- End config -----

# Generate X matrix to be used throughout simulations
# There will be one X matrix for each level of n
for (idx_n in 1:length(n_levels)) {
	n = n_levels[idx_n]
	X = matrix(rnorm(2*n), n, 2)
	saveRDS(X, file = sprintf("xmat-n%d.rds", idx_n))
}

for (idx_sigma in seq_along(sigma_levels)) {
for (idx_n in seq_along(n_levels)) {
	sigma = sigma_levels[idx_sigma]
	n = n_levels[idx_n]

	# Create a folder for this level of the simulation
	# If it already exists, skip it
	dd = sprintf("sigma%d_n%d", idx_sigma, idx_n)
	if (dir.exists(dd)) { next }
	dir.create(dd)

	# Generate launch script and save to file launch.R in run folder
	# The script sets variables particular to this level of the simulation,
	# then calls sim.R to run the simulation.
	ff = sprintf("%s/launch.R", dd)
	script = paste(sep = "\n",
		sprintf("N_sim = %d", N_sim),
		sprintf("beta_true = %s", print_vector(beta_true)),
		sprintf("sigma_true = %g", sigma),
		sprintf("xmat_file = \"../xmat-n%d.rds\"", idx_n),
		"",
		"source(\"../sim.R\")\n"
	)
	cat(script, file = ff)
}
}

