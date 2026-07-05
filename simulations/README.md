# Stopping-Time Simulations

This project simulates belief updating under alternative update rules and compares the resulting stopping-time distributions.

## How to run

Use the project virtual environment and run:

```powershell
.\.venv\Scripts\python.exe main.py
```

## What `main.py` does

`main.py` runs Monte Carlo simulations for each update rule in `UPDATE_TYPES` and for each symmetric threshold level in `THRESHOLD_LEVELS`.

A threshold level such as `0.40` is interpreted symmetrically around `0.5`, so it corresponds to stopping bounds `(0.10, 0.90)`.

## Output files

Running `main.py` produces:

- `stopping_time_summary.csv`: long-format summary table across rules and thresholds
- `stopping_time_mean_by_threshold.csv` and related metric tables: matrix-format summaries
- `stopping_time_table.tex`: LaTeX table with quantiles and means
- `stopping_time_histograms_threshold_*.png`: histogram panels by threshold
- `stopping_time_ecdf_threshold_*.png`: ECDF plots by threshold

## Main code files

- `update_rules.py`: benchmark and bias-based belief update rules
- `signal_technology.py`: experimental signal process
- `simulation.py`: one stopping-time simulation for a given rule and threshold
- `stopping.py`: stopping condition
- `main.py`: Monte Carlo driver and output generation
