# Narrative Belief Updating

This repository contains the MATLAB code, data, and simulation files accompanying the paper

**Fooling Yourself: How Narratives Shape Beliefs**  
by Andrea Albertazzi, Paolo Pin, Marco Stimolo, and Alessandro Stringhi

The repository reproduces the estimation, behavioral calibration, bootstrap inference, simulations, and figures reported in the paper.

## Repository structure

```
.
├── behavioral-calibration/
│   ├── bootstrap4_apr23_26.m
│   ├── data_narrative_with_followup.xls
│   └── README.md
│
├── calibration/
│   ├── original_data.mat
│   ├── calibration.m
│   └── README.md
│
├── simulations/
│   ├── ...
│   └── README.md
│
└── Narratives.pdf
```

Each folder contains its own README with instructions for reproducing the corresponding part of the analysis.

## Requirements

The code is written in MATLAB. No external toolboxes are required beyond standard MATLAB functionality unless explicitly stated in the corresponding folder README.

## Reproducing the results

The repository is organized by analysis stage:

1. **Calibration** estimates the structural model from the experimental data.
2. **Behavioral calibration** estimates behavioral types using the experimental dataset and bootstrap procedures.
3. **Simulations** generate the numerical results and figures reported in the paper.

The individual folder READMEs provide detailed instructions for running each component.

## Paper

The latest version of the manuscript is included in this repository. Please note that the manuscript may be updated while the code remains unchanged.
