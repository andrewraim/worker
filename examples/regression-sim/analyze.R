sigma_levels = c(1, 2, 3)
n_levels = c(50, 100, 200)

sim_res = matrix(NA, length(sigma_levels), length(n_levels))
rownames(sim_res) = sprintf("sigma%d", seq_along(sigma_levels))
colnames(sim_res) = sprintf("n%d", seq_along(n_levels))

for (idx_sigma in seq_along(sigma_levels)) {
for (idx_n in seq_along(n_levels)) {
	sigma = sigma_levels[idx_sigma]
	n = n_levels[idx_n]

	# Identify the correct directory and results file
	dd = sprintf("sigma%d_n%d", idx_sigma, idx_n)
	ff = sprintf("%s/%s", dd, "results.Rdata")
	if (!file.exists(ff)) {
		printf("File does not exist: %s\n", ff)
		next
	}

	# Load results from run directory into a separate environment
	env = new.env()
	load(ff, envir = env)

	# Compute summary for this run
	N_sim = env$N_sim
	beta_true = env$beta_true
	sigma2_true = env$sigma_true^2
	theta_true = c(beta_true, sigma2_true)

	beta_mat = matrix(unlist(Map(coef, env$res_lm)), N_sim, 2, byrow = TRUE)
	sigma2 = unlist(Map(sigma, env$res_lm))^2
	theta_mat = cbind(beta_mat, sigma2)

	diff = theta_mat - matrix(theta_true, N_sim, 3, byrow = TRUE)
	mse = mean(rowSums(diff^2))
	sim_res[idx_sigma, idx_n] = mse
	rm(env)
}
}

print(sim_res)
