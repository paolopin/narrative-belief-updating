README.txt
==========

This repository contains MATLAB code for analyzing belief updating under narrative distortion,
based on experimental data. The code includes data extraction, behavioral model estimation,
bootstrap inference, and figure generation for a research study.

1. Data Extraction:
Two scripts are provided to process the raw dataset `datanarrative`, which includes variables: id, treatment, belief, sign, and round. 
The script `extract_data.m` builds subject-level matrices of beliefs and signals in the order they appear in the data, 
without transformation. This version is used to generate Figure 1. 
The script `extract_data_order.m` reorders data so that all subjects start below belief 0.5: if a subject's first belief is 
above 0.5, both beliefs and signals are symmetrically flipped. This normalization is used for model estimation and Figure 2.

2. Figure Generation:
The script `boxchart_initial_final.m` uses the unordered data to produce Figure 1. It shows boxplots of initial and final beliefs
for both control and narrative groups, and reports bootstrap p-values from a one-sided test (null: Control ≤ Narrative).
The script `compare_first_guess.m` uses the ordered data to produce Figure 2. It compares the absolute deviation of initial beliefs
from 0.5 across treatments, plots overlapping histograms, and reports a two-sided bootstrap p-value for the difference in means.

3. Behavioral Model Estimation:
The core estimation is done via `estimate_behavioral_model.m`, which implements an EM algorithm to recover:
(i) a 3x3 matrix Pi_hat representing signal misperception (probability that a signal of type i is perceived as j),
and (ii) sigma2_hat, the variance of normally distributed noise added to Bayesian belief updates.
The algorithm infers latent signal perception posteriors (gamma) at each time step and updates parameters until convergence.

4. Bootstrap Estimation:
To assess uncertainty in the estimated parameters, `bootstrap_behavioral_model.m` runs the EM procedure on resampled versions
of the input data matrix (either control or treatment). The function stores the six off-diagonal elements of Pi and the value of sigma²
for each bootstrap sample, saving results to a .mat file. The bootstrap is designed to be robust: failed iterations are skipped with a warning.

5. Bootstrap Analysis and Comparison:
The script `analyze_bootstrap_results.m` loads the bootstrap results and compares control and narrative treatments.
It plots histograms of the estimated parameters for each group and displays the distribution of the key contrast 
Δ = Pi(2,1) − Pi(2,3). It also reports bootstrap confidence intervals and two-sided p-values for selected parameter differences 
across groups, including sigma². Results are printed to the console and histograms are saved as PNG files.

6. Usage:
Load the raw data table `datanarrative` into MATLAB. Then run `extract_data.m` and `extract_data_order.m` to create
the data matrices. Use the extracted matrices to generate figures, run estimation, or perform bootstrap analysis.
Key example calls:
   boxchart_initial_final(control_matrix, treatment_matrix);
   compare_first_guess(control_matrix, treatment_matrix);
   [Pi, sigma2, gamma] = estimate_behavioral_model(control_first5);
   bootstrap_behavioral_model(control_matrix, 1000, 'control');
   bootstrap_behavioral_model(treatment_matrix, 1000, 'treatment');
   analyze_bootstrap_results;

No special toolbox is required. The code manually implements the normal PDF to avoid relying on the Statistics Toolbox.
Please cite the accompanying paper if using this code for academic work.

Author: Paolo Pin  
Date: July 2025
