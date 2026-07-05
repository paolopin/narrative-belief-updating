# Behavioral Calibration

This folder contains the MATLAB code used to estimate the behavioral types from the experimental data.

## Files

- `bootstrap4_apr23_26.m` – Main MATLAB script. It estimates the behavioral types using a bootstrap procedure and generates the results reported in the paper.
- `data_narrative_with_followup.xls` – Experimental dataset used as input for the estimation.

## Usage

Place both files in the same directory and run

```matlab
bootstrap4_apr23_26
```

The script reads the experimental data, performs the bootstrap estimation, and saves the resulting estimates.

## Output

The script generates the estimated behavioral-type shares and the corresponding bootstrap results reported in the paper.
