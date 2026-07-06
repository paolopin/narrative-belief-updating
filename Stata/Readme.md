# Stata

This folder contains the Stata code and cleaned experimental dataset used to reproduce the main empirical results reported in the paper.

## Files

- `replication_APSS_narratives.do` – Main replication script.
- `data_cleaned.dta` – Cleaned experimental dataset.

## Usage

Set the working directory to this folder and run

```stata
do replication_APSS_narratives.do
```

The script reproduces the empirical analysis reported in the paper, including descriptive statistics, hypothesis tests, regressions, and figures.

The script assumes that `data_cleaned.dta` is located in the same folder.
