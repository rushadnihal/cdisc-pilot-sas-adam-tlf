# CDISC Pilot Study in SAS: SDTM to ADaM to TLFs

A portfolio project that derives ADaM analysis datasets (ADSL, ADAE, ADTTE) from SDTM using SAS, produces tables and figures, fits a Cox model and a repeated measures model, and checks the derived datasets against the published PHUSE ADaM files with PROC COMPARE. The data are from the public CDISC pilot study (CDISCPilot01), an Alzheimer's disease trial of xanomeline transdermal system (low dose 54 mg, high dose 81 mg) versus placebo.

This is a skills demonstration of SAS programming and CDISC standards, not a new research finding. No claims are made about the drug.

## Data source
- SDTM: `phuse-org/phuse-scripts`, folder `data/sdtm/cdiscpilot01` (in `data/sdtm/`)
- ADaM reference (QC, and input to the mixed model only): `phuse-org/phuse-scripts`, folder `data/adam/cdisc` (in `data/adam_ref/`)
- 306 screened subjects, 254 randomized (Placebo 86, Low Dose 84, High Dose 84)

## What is in the repository

| Program | Purpose | Main outputs |
|---|---|---|
| `00_setup.sas` | Path macro variable, libnames, reads the SDTM transport files | `logs/00_setup_log.html` |
| `00_explore_sdtm.sas` | Looks at the SDTM before deriving anything | `docs/00_explore_sdtm_results.html` |
| `01_adsl.sas` | Subject-level analysis dataset (254 subjects, 48 variables) | `docs/adsl_spec.md` |
| `02_adae.sas` | Adverse events analysis dataset (1,191 records, 55 variables) | `docs/adae_spec.md` |
| `03_adtte.sas` | Time to first dermatologic adverse event (254 subjects, 26 variables) | `docs/adtte_spec.md` |
| `90_qc_adsl.sas`, `91_qc_adae.sas`, `92_qc_adtte.sas` | PROC COMPARE against the PHUSE reference datasets | `docs/9x_qc_*_results.html` |
| `04_tables.sas` | Tables 1 to 6: populations, baseline, disposition, exposure, adverse event overview, adverse events by body system and term | `output/04_tables.rtf` |
| `05_km_cox.sas` | Kaplan-Meier curves, log-rank test, Cox model, proportional hazards check (Figure 1, Tables 7 to 9) | `output/05_km_cox.rtf`, `output/05_km_*.png` |
| `06_mixed_model.sas` | ANCOVA, dose response test and repeated measures model for ADAS-Cog(11) (Tables 10 to 12, Figure 2) | `output/06_mixed_model.rtf`, `output/06_adascog_lsmeans.png` |

Every run has its log in `logs/`, the Results viewer output in `docs/`, and each program has a line in `docs/validation_checklist.md`.

```
├── README.md
├── data/
│   ├── sdtm/       # SDTM .xpt files
│   ├── adam_ref/   # PHUSE reference ADaM .xpt files (QC and ADQSADAS input)
│   └── adam/       # derived ADaM datasets (created by the programs, not committed)
├── programs/       # numbered SAS programs, run in order
├── output/         # RTF tables and PNG figures
├── logs/           # saved SAS logs
└── docs/           # dataset specifications, validation checklist, saved results
```

## Results at a glance

These numbers are re-derived outside SAS (pandas and scipy) before each SAS program was written, and the SAS output was compared with them.

**Time to first dermatologic adverse event (safety population)**
- Events: 29 of 86 (Placebo), 62 of 84 (Low Dose), 61 of 84 (High Dose). Median time: not reached, 33 days, 36 days.
- Log-rank chi-square 60.27, p < 0.0001.
- Cox hazard ratio versus placebo: Low Dose 4.15 (95% CI 2.65 to 6.50), High Dose 5.03 (3.18 to 7.94). High versus Low: 1.21 (0.85 to 1.73).
- Proportional hazards check (supremum test): p = 0.23 (Low Dose), p = 0.35 (High Dose).

**ADAS-Cog(11) change from baseline (efficacy population; higher score is worse)**
- Week 24 ANCOVA with last observation carried forward: LS mean change 2.47 (Placebo), 2.01 (Low), 1.47 (High). Differences versus placebo: -0.47 (p = 0.57) and -1.01 (p = 0.23). Treatment test p = 0.49.
- Dose response test: -0.96 per full dose step (p = 0.24).
- Repeated measures model (observed scores, unstructured covariance, Kenward-Roger): treatment by visit p = 0.29. Week 24 differences versus placebo: -0.59 (p = 0.56) and -0.83 (p = 0.44).
- No treatment effect on ADAS-Cog is shown here. There is no adjustment for multiple comparisons.

## QC against the PHUSE ADaM files

| Dataset | Result |
|---|---|
| ADSL | 253 of 254 records equal on all 48 variables. One value differs: BMIBLGR1 for subject 01-702-1082 (reference `<25`, derived blank, because the subject has no baseline weight). |
| ADAE | All 1,191 records equal on all 55 variables. |
| ADTTE | AVAL, ADT, CNSR and all other values equal. One variable differs by design: EVNTDESC, where the reference text contains typos ("Dematologic Event Occured"), corrected here. |

The remaining differences reported by PROC COMPARE are attributes only (character lengths and a few formats). Details are in `docs/validation_checklist.md`.

## How to reproduce

Platform: SAS OnDemand for Academics (SAS Studio).

1. Create a folder in your SAS home directory, for example `cdisc_pilot`, with subfolders `data/sdtm`, `data/adam`, `data/adam_ref`, `programs`, `output`, `logs`. Upload this repository's `data/sdtm` and `data/adam_ref` contents, and the programs.
2. Edit the one hard-coded path, `%let root = ...;`, near the top of each program so it points to your folder.
3. Run the programs in this order: `00_setup`, `01_adsl`, `02_adae`, `03_adtte`, `90_qc_adsl`, `91_qc_adae`, `92_qc_adtte`, `04_tables`, `05_km_cox`, `06_mixed_model`. (`00_explore_sdtm` is optional.)
4. Check each log for errors, warnings and "uninitialized variable" notes. The saved logs in this repository show 0 errors and 0 warnings for the final run of every program.

## Methods and decisions

- **Treatment variables.** TRT01A and TRT01P both equal the randomized arm (ARM). Twelve subjects were randomized to Xanomeline High Dose (ARM) but their actual arm in DM (ACTARM) is Low Dose, and their only exposure record is 54 mg. As in the PHUSE reference, they are analysed as High Dose.
- **Population.** The 52 screen failures are not in ADSL. Safety, ITT and efficacy flags follow the reference data (safety 254 treated subjects, efficacy 234).
- **Cumulative and average dose** are as planned (from treatment arm and dates), not measured dose.
- **BMI group** is blank for subject 01-702-1082, who has no baseline weight.
- **Time to event.** The event is the first treatment-emergent dermatologic adverse event, counted from first dose. Subjects without the event are censored at their date of discontinuation or completion (RFENDT), as in the reference. Ties use the Efron method in PROC PHREG.
- **Baseline tables** show no p-values, because the arms are randomized.
- **Table 6** sorts body systems and preferred terms by descending count, with ties sorted alphabetically.
- **Mixed model.** The model uses baseline, treatment, visit, treatment by visit, site group and baseline by visit, with an unstructured covariance and Kenward-Roger degrees of freedom.

## Limitations

- **ADQSADAS is not derived here.** The mixed model reads the published PHUSE ADQSADAS dataset, so Tables 10 to 12 check the modelling code, not the ADAS-Cog derivation (visit windows, last observation carried forward, baseline).
- **No multiplicity adjustment** is applied to any p-value, and none of the tests is pre-specified for this project.
- **Reference ADaM files** are the QC standard, so a match shows agreement with the published datasets, not that the published datasets are correct.
- **SAS output was not run by an automated pipeline.** Each program was run by hand in SAS Studio and the logs saved. A few runs needed fixes (ordering of table rows, clipped figure points, a stale editor tab). The checklist notes describe each one.
- **Only the programs listed above are included.** There are no listings, and no ADaM datasets for lab, vital signs or the ADAS-Cog items.

## Conventions
- Programs are numbered in run order, each with a header (purpose, inputs, outputs, author, date).
- CDISC variable names are used (USUBJID, TRT01P, TRT01A, AVAL, CNSR, and so on).
- The only hard-coded path is the macro variable `root`.
- The log of every run is saved in `logs/`.

## License and attribution
- **Code and documents written for this project** (`programs/`, `docs/` specifications and checklist, this README): MIT, see `LICENSE`.
- **Data** in `data/sdtm/` and `data/adam_ref/` come from the PHUSE `phuse-scripts` repository (MIT) and are used unchanged. Source links and the license text are in `THIRD_PARTY_NOTICES.md`.
- **Redacted identifier:** the saved logs and Results output were produced in SAS OnDemand for Academics. The account user ID in file paths has been replaced with `YOUR_USER_ID`. Nothing else in the logs or results was changed.
