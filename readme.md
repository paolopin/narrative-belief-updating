# Fooling Yourself: How Narratives Shape Beliefs

This repository contains the code and data accompanying the paper

> **Fooling Yourself: How Narratives Shape Beliefs**
> Andrea Albertazzi, Paolo Pin, Marco Stimolo, and Alessandro Stringhi

The repository reproduces the empirical analysis, behavioral-type classification, and numerical simulations presented in the paper.

## Repository structure

```text
.
├── Stata/
│   └── Stata code and cleaned experimental data
│
├── behavioral-calibration/
│   └── MATLAB code for behavioral-type classification
│
└── simulations/
    └── Python code for the numerical simulations
```

Each folder contains a dedicated `README.md` describing its contents and explaining how to reproduce the corresponding results.

## Requirements

The repository uses three software environments:

* **Stata** for the empirical analysis;
* **MATLAB** for the behavioral-type classification;
* **Python** for the numerical simulations.

The behavioral-type classification assumes reporting errors follow a normal distribution truncated to ([0,1]) and uses subject-level BIC comparisons among the four candidate updating rules described in the paper.

See the individual folder READMEs for detailed instructions.

## Citation

If you use this code, please cite:

> Albertazzi, A., Pin, P., Stimolo, M., & Stringhi, A. *Fooling Yourself: How Narratives Shape Beliefs.*

