# Validation Checklist

Complete one section per program after each run. Save the log in `logs/` with the same base name as the program.

## Per-program log review

| Program | Run date | Log saved | 0 errors | 0 unexplained warnings | No uninitialized variables | No unintended merge notes | Reviewed by |
|---|---|---|---|---|---|---|---|
| 00_setup.sas | 2026-11-15 | Yes (logs/00_setup_log.html, re-run with MH and VS, 19 datasets) | Yes | Yes | Yes | Yes | rushadnihal / Claude |
| 00_explore_sdtm.sas | 2026-11-15 | Yes (logs/00_explore_sdtm_log.html, run 2) | Yes | Yes | Yes | Yes | rushadnihal / Claude |
| 01_adsl.sas | 2026-11-15 | Yes (logs/01_adsl_log.html) | Yes | Yes | Yes | Yes | rushadnihal / Claude | |
| 90_qc_adsl.sas | 2026-11-15 | Yes (logs/90_qc_adsl_log.html) | Yes | Yes | Yes | Yes | rushadnihal / Claude |
| 02_adae.sas | | | | | | | |
| 03_adtte.sas | | | | | | | |
| 04_tables.sas | | | | | | | |
| 05_km_cox.sas | | | | | | | |
| 06_mixed_model.sas | | | | | | | |

## Dataset checks

| Dataset | One record per expected key | Subject count matches SDTM | Variable names, labels, types per spec | No unexpected missing values | Derivations spot-checked |
|---|---|---|---|---|---|
| ADSL | Yes (254 rows, 254 subjects) | Yes (254 randomized; 52 screen failures excluded by design) | Yes (labels and lengths per docs/adsl_spec.md; 48 variables) | Only expected: 1 subject without baseline weight/BMI | Yes: flag, dose, disposition, site and group counts match PHUSE ADSL; see 01_adsl_results.html |
| ADAE | | | | | |
| ADTTE | | | | | |

## QC against PHUSE ADaM reference (PROC COMPARE)

| Dataset | Compare run | Differences found | Explanation / resolution |
|---|---|---|---|
| ADSL | 2026-11-15 (docs/90_qc_adsl_results.html) | 1 value: BMIBLGR1 for 01-702-1082 (reference `<25`, derived blank). Attribute differences only: lengths of AGEU, RACE, ETHNIC, RFSTDTC, RFENDTC. | Expected and documented in docs/adsl_spec.md: subject has no baseline weight, so BMI is missing and no group is assigned. 253 of 254 records match on all 48 variables. |
| ADAE | | | |
| ADTTE | | | |

## Output checks

| Output | Numbers cross-checked against dataset | Titles and footnotes correct | Notes |
|---|---|---|---|
| | | | |

## Sign-off
- Completed by:
- Date:

## Notes

- **00_explore_sdtm.sas, run 1:** 1 error and 2 empty results. (1) PROC PRINT of SDTM.TS stopped with "Invalid characters were present in the data" (non-ASCII character in TSVAL); TS is not used downstream, so the print was removed. (2) The ADAS-Cog sections selected 0 rows because the QS category is "ALZHEIMER'S DISEASE ASSESSMENT SCALE", not a value containing "ADAS"; the filter was corrected. Run 2 (after the fixes) has 0 errors and 0 warnings and the ADAS-Cog sections return 12,241 records. The run 1 log is kept for the record. In run 2 the two QS titles read "ALZHEIMER-Cog" because of a find-and-replace in SAS Studio; the committed program has the correct titles.

- **00_setup.sas, re-run:** after adding MH and VS (needed for ADSL baseline height, weight, BMI and disease duration) the program was re-run: 0 errors, 0 warnings, 19 datasets. The only "ERROR" text in the log is the source line of the missing-file message inside the macro, which did not fire.
