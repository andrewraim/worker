# Assume that this script has been invoked from the launch script. Necessary
# libraries should have already been loaded and variables should have been
# defined.
source("../util.R")

# ----- Check for arguments set by the launch script -----
stopifnot(exists("beta_true"))
stopifnot(exists("sigma_true"))
stopifnot(exists("xmat_file"))
stopifnot(exists("N_sim"))
stopifnot(exists("mcmc_reps"))
stopifnot(exists("mcmc_burn"))
stopifnot(exists("mcmc_thin"))
stopifnot(exists("report_period"))

# ----- Set up data that will be fixed through simulation -----
X = readRDS(xmat_file)
n = nrow(X)
d = length(beta_true)
mu_true = as.numeric(X %*% beta_true)

res_lm = list()
res_gibbs = list()

for (s in 1:N_sim) {
	logger("*** Simulation %d ***\n", s)

	# Generate data
	y = rnorm(n, mu_true, sigma_true)

	# Fit lm
	lm_out = lm(y ~ X - 1)
	res_lm[[s]] = lm_out

	# TBD: Run Gibbs sampler
}

save.image("results.Rdata")
