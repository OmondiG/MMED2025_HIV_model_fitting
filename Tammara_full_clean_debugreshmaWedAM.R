# HIV Model Fitting for Evaluating Interventions: A Simulation Exercise


# Things I noted:
# ProgRt being used different in the two ODE systems



# ============================================================
# Setup
# ============================================================

rm(list = ls())
graphics.off()

require(dplyr)
require(boot)
require(deSolve)
require(ellipse)
require(ggplot2)

# ============================================================
# Global Parameters and Initial Conditions
# ============================================================

initial_prevalence <- exp(-9.5)
time_sequence <- seq(1976, 2025, by = 1)
initial_conditions <- c(S = 1 - initial_prevalence, I1 = initial_prevalence, I2 = 0, I3 = 0, I4 = 0, CI = 0, CD = 0)
infection_states <- paste0('I', 1:4)

# ============================================================
# Disease Model Functions
# ============================================================

SImodel <- function(time, state, parameters) {
	with(c(parameters, as.list(state)), {
		I <- I1 + I2 + I3 + I4
		N <- I + S
		transmission_rate <- Beta * exp(-alpha * I / N)
		
		dS <- birthRt * N - deathRt * S - transmission_rate * S * I / N
		dI1 <- transmission_rate * S * I / N - progRt * I1 - deathRt * I1
		dI2 <- progRt * I1 - progRt * I2 - deathRt * I2
		dI3 <- progRt * I2 - progRt * I3 - deathRt * I3
		dI4 <- progRt * I3 - progRt * I4 - deathRt * I4
		dCI <- transmission_rate * S * I / N
		dCD <- progRt * I4
		
		list(c(dS, dI1, dI2, dI3, dI4, dCI, dCD))
	})
}

cMax <-0.7; cRate <- 0.5; cHalf <- 1998
tt <- seq(1976, 2025, by = 0.1)
control_effect <- pmin(1, 1 - cMax / (1 + exp(-cRate * (tt - cHalf))))
plot(tt, control_effect, type = 'l')
cMax <-0.7; cRate <- 0.5; cHalf <- 1990
control_effect <- pmin(1, 1 - cMax / (1 + exp(-cRate * (tt - cHalf))))
lines(tt, control_effect, col = 'red')
cMax <-0.7; cRate <- 0.5; cHalf <- 2002
control_effect <- pmin(1, 1 - cMax / (1 + exp(-cRate * (tt - cHalf))))
lines(tt, control_effect, col = 'blue')

cMax <-0.7; cRate <- 0.5; cHalf <- 1998
tt <- seq(1976, 2025, by = 0.1)
control_effect <- pmin(1, 1 - cMax / (1 + exp(-cRate * (tt - cHalf))))
plot(tt, control_effect, type = 'l')
cMax <-0.7; cRate <- 2; cHalf <- 1998
control_effect <- pmin(1, 1 - cMax / (1 + exp(-cRate * (tt - cHalf))))
lines(tt, control_effect, col = 'red')
cMax <-0.7; cRate <- 0.1; cHalf <- 1998
control_effect <- pmin(1, 1 - cMax / (1 + exp(-cRate * (tt - cHalf))))
lines(tt, control_effect, col = 'blue')

cMax <-0.1; cRate <- 0.5; cHalf <- 1998
tt <- seq(1976, 2025, by = 0.1)
control_effect <- pmin(1, 1 - cMax / (1 + exp(-cRate * (tt - cHalf))))
plot(tt, control_effect, type = 'l', ylim = c(-0.2,1))
cMax <-0.5; cRate <- 0.5; cHalf <- 1998
control_effect <- pmin(1, 1 - cMax / (1 + exp(-cRate * (tt - cHalf))))
lines(tt, control_effect, col = 'red')
cMax <-0.9; cRate <- 0.5; cHalf <- 1998
control_effect <- pmin(1, 1 - cMax / (1 + exp(-cRate * (tt - cHalf))))
lines(tt, control_effect, col = 'blue')
cMax <-1.1; cRate <- 0.5; cHalf <- 1998
control_effect <- pmin(1, 1 - cMax / (1 + exp(-cRate * (tt - cHalf))))
lines(tt, control_effect, col = 'green')

SI4control <- function(time, state, parameters) {
	with(c(as.list(state), parameters), {
		N <- sum(state[1:5])
		I <- I1 + I2 + I3 + I4
		lambda <- Beta * exp(-alpha * I / N)
		g <- 4 * progRt
		control_effect <- min(1, cMax+(1-cMax)*exp(-(time-cStart)*cRate))
		
		dS <- birthRt * N - control_effect * lambda * S * I / N - deathRt * S
		progression <- g * c(I1, I2, I3, I4)
		dI <- c(control_effect * lambda * S * I / N, progression[1:3]) - progression - deathRt * c(I1, I2, I3, I4)
		dCI <- control_effect * lambda * S * I / N
		dCD <- progression[4]
		
		list(c(dS, dI, dCI, dCD))
	})
}

create_disease_parameters <- function(Beta = 0.6 ## transmission coefficient when prevalence is 0 
																												, alpha = 3.5 ## for transmission coefficient: decline with prevalence
																												, progRt = (1/15) ## rate of of progression through each of the I classes, for 10 years total
																												, birthRt = .03 ## birth rate, 3% of people give birth per year
																												, deathRt = 1/60 ## 60 year natural life expectancy
																												, cMax = 0.7 # 1 - THIS is intervention effect
																												, cRate = 0.5
																												, cStart = 1998
){
	return(as.list(environment())) ## ARG
}

# ============================================================
# Simulation and Sampling Functions
# ============================================================

simulate_epidemic <- function(initial_conditions, time_sequence, model_function, parameters) {
sim_data <- as.data.frame(lsoda(initial_conditions, time_sequence, model_function, parms = parameters))
	sim_data$I <- rowSums(sim_data[, infection_states])
	sim_data$N <- rowSums(sim_data[, c('S', infection_states)])
	sim_data$P <- sim_data$I / sim_data$N
	return(sim_data)
}

simulate_epidemic(initial_conditions, time_sequence, SI4control, create_disease_parameters())
summary(simulate_epidemic(initial_conditions, time_sequence, SI4control, create_disease_parameters(cMax = 1.1)))
## I THINK THIS IS THE PROBLEM


sample_epidemic <- function(simulated_data, sample_times = seq(1985, 2024, by = 1), sample_sizes = rep(1000, length(sample_times))) {
	prevalence <- simulated_data$P[round(simulated_data$time, 4) %in% round(sample_times, 4)]
	num_positive <- rbinom(length(sample_sizes), sample_sizes, prevalence)
	lci <- mapply(function(x, n) binom.test(x, n)$conf.int[1], x = num_positive, n = sample_sizes)
	uci <- mapply(function(x, n) binom.test(x, n)$conf.int[2], x = num_positive, n = sample_sizes)
	
	data.frame(time = sample_times, numPos = num_positive, numSamp = sample_sizes, sampPrev = num_positive / sample_sizes, lci = lci, uci = uci)
}

# sim1 <- simulate_epidemic(initial_conditions, time_sequence, SI4control, create_disease_parameters(cMax = 1.1))
# sample_epidemic(sim1)

# sim1 <- simulate_epidemic(initial_conditions, time_sequence, SI4control, create_disease_parameters(cMax = 1.1))
# sample_epidemic(sim1)

sim2 <- simulate_epidemic(initial_conditions, time_sequence, SI4control, create_disease_parameters(cMax = 0.9))
simdata2 <- sample_epidemic(sim2)



# ============================================================
# Estimation Functions
# ============================================================

substitute_parameters <- function(estimated_params, fixed_params) {
	for (name in names(estimated_params)) {
		if (grepl('log_', name)) {
			param_name <- gsub('log_', '', name)
			fixed_params[[param_name]] <- exp(estimated_params[[name]])
		} else if (grepl('logit_', name))  {
			param_name <- gsub('logit_', '', name)
		  fixed_params[[param_name]] <- 1/(1+exp(-estimated_params[[name]]))
		} else {
			fixed_params[[name]] <- estimated_params[[name]]
		}
	}
	return(fixed_params)
}

substitute_parameters(c(log_cRate = 0.5, logit_cMax = log(0.2/0.8)), create_disease_parameters())

calculate_nll <- function(parameters, observed_data, model_function) {
	# browser()
	simulated_data <- simulate_epidemic(initial_conditions, time_sequence, model_function, parameters)
	matched_times <- simulated_data$time %in% observed_data$time
	if (any(is.na(simulated_data$P[matched_times])) || any(simulated_data$P[matched_times] < 0 | simulated_data$P[matched_times] > 1)) {
		warning(paste0("Invalid prevalence values (NA or outside [0,1]) detected"))
		# warning(paste0("Invalid prevalence values (NA or outside [0,1]) detected", parameters$cMax ))
		return(1e6)
	}
	nll_values <- dbinom(observed_data$numPos, observed_data$numSamp, prob = simulated_data$P[matched_times], log = TRUE)
	return(-sum(nll_values))
}

calculate_nll(create_disease_parameters(), simdata2, SI4control)

estimate_mle <- function(observed_data, model_function, initial_guess, fixed_params) {
  
  # browser()
  
	objective_function <- function(fit_params) {
	  # browser()
		updated_params <- substitute_parameters(fit_params, fixed_params)
		calculate_nll(updated_params, observed_data, model_function)
	}
	
	mle_fit_pre <- optim(par = initial_guess, fn = objective_function, method = "SANN", control = list(trace = 1, maxit = 150))
	mle_fit <- optim(par = mle_fit_pre$par, fn = objective_function, method = "Nelder-Mead", control = list(trace = 1, maxit = 1000), hessian = TRUE)
	
	estimated_params <- mle_fit$par
	covariance_matrix <- solve(mle_fit$hessian)
	standard_errors <- sqrt(diag(covariance_matrix))
	
	list(params = estimated_params, se = standard_errors, loglik = mle_fit$value, fit = mle_fit, fisherInfMatrix = covariance_matrix)
}

estimate_lse <- function(observed_data, model_function, initial_guess, fixed_params) {
	lse_objective <- function(fit_params) {
		updated_params <- substitute_parameters(fit_params, fixed_params)
		simulated_data <- simulate_epidemic(initial_conditions, time_sequence, model_function, updated_params)
		
		matched_times <- simulated_data$time %in% observed_data$time
		observed_prev <- observed_data$numPos / observed_data$numSamp
		predicted_prev <- simulated_data$P[matched_times]
		sum((observed_prev - predicted_prev)^2)
	}
	
	lse_fit <- optim(par = initial_guess, fn = lse_objective, method = "Nelder-Mead", control = list(trace = 1, maxit = 1000), hessian = TRUE)
	
	estimated_params <- lse_fit$par
	covariance_matrix <- solve(lse_fit$hessian)
	standard_errors <- sqrt(diag(covariance_matrix))
	
	list(params = estimated_params, se = standard_errors, ssr = lse_fit$value, fit = lse_fit)
}

# ============================================================
# Run Simulation, Sampling, Estimation and Grid Evaluation
# ============================================================

# gather_cmax <- gather_crate <- c()
# for (ii in 1:100){
# set.seed(45)

true_params <- create_disease_parameters()
simulated_data <- simulate_epidemic(initial_conditions, time_sequence, SI4control, true_params)
observed_data <- sample_epidemic(simulated_data)

plot(simulated_data$time, simulated_data$P, type = 'l', col = 'red', ylab = 'Prevalence', xlab = 'Year',  xlim = c(1960, 2050), ylim = c(0, max(simulated_data$P, observed_data$uci)))
points(observed_data$time, observed_data$sampPrev, col = 'blue', pch = 16)
# Add confidence intervals
arrows(observed_data$time, observed_data$lci, observed_data$time, observed_data$uci, angle = 90, code = 3, length = 0.05, col = 'blue')
legend('topleft', legend = c('Simulated Prevalence', 'Observed Prevalence', '95% CI'), col = c('red', 'blue', 'blue'), pch = c(NA, 16, NA), lty = c(1, NA, 1), bty = 'n')

initial_guess <- c(logit_cMax = log(0.6/0.4), log_cRate = log(0.4))
# initial_guess <- c(log_cMax = log(1), log_cRate = log(3))
data1 <- readRDS("/Users/tkoh/Documents/MMED2025/MMED2025_HIV_model_fitting/simPdata_list1.rds")
data1 <- data1[[1]]
mle_result <- estimate_mle(data1, SI4control, initial_guess, true_params)
exp( mle_result$params['log_cRate'])
1/(1+exp(-mle_result$params['logit_cMax']))
# gather_crate[ii] <- exp( mle_result$params['log_cRate'])
# gather_cmax[ii] <- 1/(1+exp(-mle_result$params['logit_cMax']))
true_params[c('cMax','cRate')]

# }
  
# lse_result <- estimate_lse(observed_data, SI4control, initial_guess, true_params)

cat("MLE Estimates:", exp(unname(mle_result$params)), "\n")
# cat("LSE Estimates:", exp(unname(lse_result$params)), "\n")
true_params[c('cMax','cRate')]


# ============================================================
# Likelihood Grid Evaluation Using Profile Likelihood Approach
# ============================================================

logit <- function(x){
 log(x/(1-x)) 
}

invlogit <- function(x){
  1/(1+exp(-x)) 
}

# Define profile likelihood objective function
objXcMax_cRate <- function(cMax, cRate, fixed_params = true_params) {
	fit_params <- c(logit_cMax = logit(cMax), log_cRate = log(cRate))
	updated_params <- substitute_parameters(fit_params, fixed_params)
	calculate_nll(updated_params, observed_data, SI4control)
}

# Vectorize it to evaluate over a grid
objXcMax_cRateVEC <- Vectorize(objXcMax_cRate, vectorize.args = c("cMax", "cRate"))

# Create parameter grids
res <- 50
cMax_seq <- seq(0.6, 0.8, length.out = res)
cRate_seq <- seq(0.1, 1.5, length.out = res)

# Evaluate likelihood surface using outer()
likelihood_surface <- outer(cMax_seq, cRate_seq, objXcMax_cRateVEC)

# ggplot(data, aes(X, Y, fill= Z)) + 
#   geom_tile()

# Confidence cutoff using chi-square approximation
min_likelihood <- min(likelihood_surface)
max_likelihood <- max(likelihood_surface)
conf_cutoff <- min_likelihood + qchisq(0.95, df = 2) / 2

# Plot the profile likelihood surface

par(cex = 1.2)
plot(1, 1, type = 'n', log = '',
		 xlim = range(cMax_seq), ylim = range(cRate_seq),
		 xlab = expression(c[max]), ylab = expression(c[rate]),
		 main = "-log(likelihood) contours", bty = "n")


plotlevels <- c(seq(min_likelihood, 1.5*min_likelihood, length.out = 10), seq(1.55*min_likelihood, max_likelihood, length.out = 10))

.filled.contour(cMax_seq, cRate_seq, likelihood_surface,
								levels = plotlevels,
								col = topo.colors(20))

# Add 95% profile likelihood contour
contour(cMax_seq, cRate_seq, likelihood_surface, levels = conf_cutoff,
				col = "black", lwd = 2, labels = "", labcex = 0.2, add = TRUE)

# Add Fisher information ellipse
lines(exp(ellipse(mle_result$fisherInfMatrix, centre = mle_result$params, level = .95)), lty = 2)

# Add MLE and true parameter points
points(invlogit(mle_result$params['logit_cMax']), exp(mle_result$params['log_cRate']), pch = 16, col = 'black')
points(true_params$cMax, true_params$cRate, pch = 16, col = 'red')

# Add legend
legend("topleft",
			 legend = c('Truth', 'MLE', '95% CI (Profile Likelihood)', '95% CI (Fisher Information)'),
			 lty = c(NA, NA, 1, 2), pch = c(16, 16, NA, NA),
			 col = c('red', rep('black', 3)), bg = 'white', bty = 'n')

