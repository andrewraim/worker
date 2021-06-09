# Assume that this script has been invoked from the launch script. Necessary
# libraries should have already been loaded and variables should have been
# defined.
source("../util.R")

rep_sleep_time = 0.01

# ----- Check for arguments set by the launch script -----
stopifnot(exists("beta_true"))
stopifnot(exists("sigma_true"))
stopifnot(exists("xmat_file"))
stopifnot(exists("N_sim"))

# ----- Set up data that will be fixed through simulation -----
X = readRDS(xmat_file)
n = nrow(X)
d = length(beta_true)
mu_true = as.numeric(X %*% beta_true)

res_lm = list()
res_gibbs = list()

eye = diag(nrow = n)


for (s in 1:N_sim) {
	logger("Rep %d\n", s)

	# Generate data
	y = rnorm(n, mu_true, sigma_true)

	# Compute MLE in closed form
	# Try to avoid making n x n matrices
	XtX = t(X) %*% X
	Xty = crossprod(X, y)
	Q = sum(y^2) - t(Xty) %*% solve(XtX, Xty)
	beta_hat = solve(XtX, Xty)
	sigma2_hat = Q / n

	res_lm[[s]] = c(beta_hat, sigma2_hat)

	# A sleep is here to give the sense of a more computationally demanding
	# simulation
	Sys.sleep(rep_sleep_time)
}

save.image("results.Rdata")
