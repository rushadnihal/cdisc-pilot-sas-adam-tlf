# Validation Checklist

Complete one section per program after each run. Save the log in `logs/` with the same base name as the program.

## Per-program log review

| Program | Run date | Log saved | 0 errors | 0 unexplained warnings | No uninitialized variables | No unintended merge notes | Reviewed by |
|---|---|---|---|---|---|---|---|
| 00_setup.sas | 2026-11-15 | Yes (logs/00_setup_log.html, re-run with MH and VS, 19 datasets) | Yes | Yes | Yes | Yes | rushadnihal / Claude |
| 00_explore_sdtm.sas | 2026-11-15 | Yes (logs/00_explore_sdtm_log.html, run 2) | Yes | Yes | Yes | Yes | rushadnihal / Claude |
| 01_adsl.sas | 2026-11-15 | Yes (logs/01_adsl_log.html) | Yes | Yes | Yes | Yes | rushadnihal / Claude | |
| 90_qc_adsl.sas | 2026-11-15 | Yes (logs/90_qc_adsl_log.html) | Yes | Yes | Yes | Yes | rushadnihal / Claude |
| 02_adae.sas | 2026-11-15 | Yes (logs/02_adae_log.html) | Yes | Yes | Yes | Yes | rushadnihal / Claude |
| 91_qc_adae.sas | 2026-11-15 | Yes (logs/91_qc_adae_log.html) | Yes | Yes | Yes | Yes | rushadnihal / Claude | |
| 03_adtte.sas | 2026-11-15 | Yes (logs/03_adtte_log.html, run 2) | Yes | Yes | Yes | Yes | rushadnihal / Claude |
| 92_qc_adtte.sas | 2026-11-15 | Yes (logs/92_qc_adtte_log.html, run 2) | Yes | Yes | Yes | Yes | rushadnihal / Claude | |
| 04_tables.sas | 2026-11-15 | Yes (logs/04_tables_log.html, run 3) | Yes | Yes | Yes | Yes | rushadnihal / Claude |
| 05_km_cox.sas | 2026-11-15 | Yes (logs/05_km_cox_log.html, run 3) | Yes | Yes | Yes | Yes | rushadnihal / Claude |
| 06_mixed_model.sas | | | | | | | |

## Dataset checks

| Dataset | One record per expected key | Subject count matches SDTM | Variable names, labels, types per spec | No unexpected missing values | Derivations spot-checked |
|---|---|---|---|---|---|
| ADSL | Yes (254 rows, 254 subjects) | Yes (254 randomized; 52 screen failures excluded by design) | Yes (labels and lengths per docs/adsl_spec.md; 48 variables) | Only expected: 1 subject without baseline weight/BMI | Yes: flag, dose, disposition, site and group counts match PHUSE ADSL; see 01_adsl_results.html |
| ADAE | Yes (1,191 records, unique USUBJID+AESEQ) | Yes (225 subjects with AEs, all in ADSL) | Yes (55 variables per docs/adae_spec.md) | Only expected: 473 missing end dates, 11 year-only start dates | Yes: TEAE 1,126, dermatologic 493, first dermatologic TEAE 152 |
| ADTTE | Yes (254 rows, 254 subjects) | Yes | Yes (26 variables per docs/adtte_spec.md) | None | Yes: 152 events, 102 censored; events by arm 29 / 62 / 61; AVAL minimum 1 |

## QC against PHUSE ADaM reference (PROC COMPARE)

| Dataset | Compare run | Differences found | Explanation / resolution |
|---|---|---|---|
| ADSL | 2026-11-15 (docs/90_qc_adsl_results.html) | 1 value: BMIBLGR1 for 01-702-1082 (reference `<25`, derived blank). Attribute differences only: lengths of AGEU, RACE, ETHNIC, RFSTDTC, RFENDTC. | Expected and documented in docs/adsl_spec.md: subject has no baseline weight, so BMI is missing and no group is assigned. 253 of 254 records match on all 48 variables. |
| ADAE | 2026-11-15 (docs/91_qc_adae_results.html) | None: all 1,191 records equal on all 55 variables. Attribute differences only: character lengths of RACE, AETERM, AELLT, AEDECOD, AEHLT, AEHLGT, AESOC, AEACN, AEOUT. | Lengths follow the SDTM source here; the reference uses shorter lengths. No values affected. |
| ADTTE | 2026-11-15 (docs/92_qc_adtte_results.html) | 1 variable: EVNTDESC, 152 records (event text). Attribute differences only: formats on AGE, AGEGR1N, RACEN, TRTDUR; lengths of RACE, PARAM, EVNTDESC. | Intended: reference text "Dematologic Event Occured" is corrected to "Dermatologic Event Occurred". All other values, including AVAL, ADT, CNSR, SRCSEQ, equal. |

## Output checks

| Output | Numbers cross-checked against dataset | Titles and footnotes correct | Notes |
|---|---|---|---|
| output/04_tables.rtf, Table 1 (populations) | Yes: recomputed from ADSL (pandas): ITT/safety 86/84/84, efficacy 79/81/74, completers Week 8/16/24 74/60/56, 68/42/37, 60/28/30 | Yes | Total column is the same 254 subjects |
| Table 2 (baseline) | Yes: n, mean, SD, median, min, max for age, height, weight, BMI, education, disease duration, MMSE; sex, race, age-group counts | Yes | One subject has no baseline weight, so weight and BMI n = 83 in Low Dose; BMI group shows 1 Missing. No baseline p-values (randomized arms) |
| Table 3 (disposition) | Yes: discontinued 28/59/57, discontinued for AE 8/44/40 | Yes | |
| Table 4 (exposure) | Yes: duration, cumulative dose, average daily dose match ADSL | Yes | Dose is as planned (not measured) |
| Table 5 (TEAE overview) | Yes: any TEAE 65/77/76, related 43/72/70, severe 5/16/8, serious 0/1/2, fatal 2/1/0, dermatologic 29/62/61 | Yes | Dermatologic counts also equal the ADTTE event counts (cross-check in the log output) |
| Table 6 (TEAE by body system and term) | Partly: body-system totals for the top 4 systems and the preferred-term counts for the top system recomputed from ADAE | Yes | Ties in preferred-term counts are sorted alphabetically |

## Sign-off
- Completed by:
- Date:

## Notes

- **00_explore_sdtm.sas, run 1:** 1 error and 2 empty results. (1) PROC PRINT of SDTM.TS stopped with "Invalid characters were present in the data" (non-ASCII character in TSVAL); TS is not used downstream, so the print was removed. (2) The ADAS-Cog sections selected 0 rows because the QS category is "ALZHEIMER'S DISEASE ASSESSMENT SCALE", not a value containing "ADAS"; the filter was corrected. Run 2 (after the fixes) has 0 errors and 0 warnings and the ADAS-Cog sections return 12,241 records. The run 1 log is kept for the record. In run 2 the two QS titles read "ALZHEIMER-Cog" because of a find-and-replace in SAS Studio; the committed program has the correct titles.

- **00_setup.sas, re-run:** after adding MH and VS (needed for ADSL baseline height, weight, BMI and disease duration) the program was re-run: 0 errors, 0 warnings, 19 datasets. The only "ERROR" text in the log is the source line of the missing-file message inside the macro, which did not fire.

- **03_adtte.sas / 92_qc_adtte.sas, run 1:** `03_adtte.sas` had 2 errors from check 4 (a PROC SQL query with no FROM clause on the outer select); the ADTTE dataset itself was created correctly before the error. `92_qc_adtte.sas` had ERROR 180-322 because only the program's file name had been pasted into the editor, so nothing ran. Both were re-run (run 2) after fixing check 4 and pasting the full QC program: 0 errors, 0 warnings. Run 1 logs were not kept.

- **04_tables.sas, runs 1 to 3:** runs 1 and 2 had errors caused by an incomplete copy of the program in the editor (the paste stopped partway through the Table 1 section, and a leftover half line then broke the `%flagrow` call), not by program logic. Run 3, using the uploaded complete file, had 0 errors and 0 warnings but the log showed five "variable is uninitialized" notes from `%init`, and Table 2 rows were out of order (PROC REPORT sorts an ORDER variable by formatted value by default). Both were fixed (`call missing` in `%init`, `order=internal` in `%rpt`) and the program was re-run. The saved log, results and RTF are from that last run: 0 errors, 0 warnings, no uninitialized variables, no merge notes. The only unusual notes are 7 Cartesian product notes from the intended zero-fill cross join in `%catrows`. Earlier run logs were not kept.

- **05_km_cox.sas, runs 1 to 3:** run 1 was clean (0 errors, 0 warnings) and all numbers matched the independent calculation, but the strata sorted alphabetically (Placebo, High, Low) and the hazard ratio table showed ratios as Placebo versus xanomeline. Run 2 fixed both (dose-ordered labels, `diff=ref`) and added a contrast for high vs low dose, but the copy that was run had the contrast coefficients in the wrong order, so the line labelled "High dose vs low dose" showed 0.825 (the inverse). Run 3, with the coefficients corrected, shows 1.2118 (0.8496 to 1.7283), matching the independent calculation. The saved log, results, RTF and PNG files are from run 3. Earlier run logs were not kept. The two proportional hazards plots were saved as `05_km_ph_low_dose.png` and `05_km_ph_high_dose.png` (SAS named them `05_km_dermatologic1.png` and `05_km_dermatologic2.png`).
