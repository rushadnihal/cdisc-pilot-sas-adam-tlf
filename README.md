# CDISC Pilot Study in SAS: SDTM to ADaM to TLFs

> **Status: work in progress.** This README is a stub and will be completed once the analyses are finished and verified.

A portfolio project that derives ADaM analysis datasets from SDTM using SAS and produces tables, listings and figures (TLFs) for the public CDISC pilot study (CDISCPilot01), an Alzheimer's disease trial of xanomeline transdermal system doses versus placebo.

This is a skills demonstration of SAS programming and CDISC standards, not a new research finding.

## Data source
- SDTM: `phuse-org/phuse-scripts`, folder `data/sdtm/cdiscpilot01`
- ADaM reference (QC only): `phuse-org/phuse-scripts`, folder `data/adam/cdisc`
- Dataset names, subject counts and endpoints: *to be verified from the data and `define.xml`*

## Planned deliverables
- ADSL, ADAE, ADTTE derived from SDTM
- Demographics, disposition, exposure and adverse event tables
- Kaplan-Meier figure (PROC LIFETEST) and Cox model (PROC PHREG)
- Repeated-measures analysis (PROC MIXED), if the data supports it
- QC of derived ADaM against the published PHUSE ADaM files (PROC COMPARE)

## Repository structure
```
├── README.md
├── data/
│   ├── sdtm/      # SDTM .xpt files
│   └── adam/      # derived ADaM datasets
├── programs/      # numbered SAS programs, run in order
├── output/        # RTF tables, figures
├── logs/          # saved SAS logs from every run
└── docs/          # specifications, validation notes
```

## Planned programs
| Program | Purpose |
|---|---|
| `00_setup.sas` | Path macro variable and libnames |
| `01_adsl.sas` | Subject-level analysis dataset |
| `02_adae.sas` | Adverse events analysis dataset |
| `03_adtte.sas` | Time-to-event analysis dataset |
| `04_tables.sas` | Summary tables (RTF via ODS) |
| `05_km_cox.sas` | Kaplan-Meier and Cox model |
| `06_mixed_model.sas` | Repeated-measures model |

## How to reproduce
*To be written.* Platform: SAS OnDemand for Academics (SAS Studio).

## Methods and limitations
*To be written.*

## Conventions
- Programs are numbered in run order, each with a header (purpose, inputs, outputs, author, date).
- CDISC variable names are used (USUBJID, TRT01P, TRT01A, AVAL, CNSR, and so on).
- The only hard-coded path is the macro variable set in `00_setup.sas`.
- The log of every run is saved in `logs/`.
