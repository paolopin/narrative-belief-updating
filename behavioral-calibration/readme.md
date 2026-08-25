# Behavioral Calibration

This folder contains the MATLAB code used to classify subjects into behavioral types based on the experimental data.

## Files

* `bootstrap_aug4_26_truncated_normal.m` – Main MATLAB script. It estimates four behavioral types at the subject level using BIC, assuming reporting errors follow a normal distribution truncated to ([0,1]). Statistical uncertainty is assessed through a subject-level bootstrap procedure.
* `data_narrative_with_followup.xls` – Experimental dataset used as input for the estimation.

## Usage

Place both files in the same directory and run

```matlab
bootstrap_aug4_26_truncated_normal
```

The script reads the experimental data, estimates the four candidate behavioral models for each subject, classifies subjects according to the model with the lowest BIC, and performs 10,000 bootstrap replications separately within each treatment.

## Behavioral Types

The four candidate updating rules are:

* **Bayes** – smooth updating after diagnostic signals, with estimated reaction intensity, and no updating after nondiagnostic signals.
* **Bayes-Reset** – the same updating rule for diagnostic signals, but beliefs reset to (0.5) after a nondiagnostic signal.
* **Coarse** – diagnostic signals generate corner beliefs, while nondiagnostic signals leave beliefs unchanged.
* **Coarse-Reset** – diagnostic signals generate corner beliefs, while nondiagnostic signals reset beliefs to (0.5).

## Output

The script generates the behavioral-type shares reported in the paper, together with bootstrap confidence intervals and treatment comparisons. It also reports the estimated reaction-intensity parameter (\lambda), the reporting-error parameter (\sigma), and diagnostics for estimates close to the upper bound on (\sigma).

Bootstrap results are saved in MATLAB format and exported to Excel.
