# Sigma to Kibana NDJSON Converter

This Python script automates the conversion of Sigma YAML rules into Kibana-compatible NDJSON files suitable for import as detection rules. It leverages the Sigma CLI to convert the rules, cleans and flattens the generated JSON by removing unsupported fields and renaming others, then writes out valid NDJSON files. A simple progress indicator is displayed during processing, and detailed logs are maintained.

## Features

- **Recursive Rule Processing**: Scans a given directory for Sigma YAML (`.yml`/`.yaml`) rules.
- **Sigma Conversion**: Uses the `sigma` CLI to convert rules to JSON using a specified target and pipeline.
- **JSON Cleanup**: Flattens the `params` object to the top level, renames fields (e.g., `ruleId` to `rule_id`), and removes unsupported fields.
- **NDJSON Output**: Writes each cleaned rule as a single-line NDJSON file and creates an aggregated NDJSON file (`all_kibana_rules.ndjson`) for bulk import.
- **Progress Indicator**: Displays a simple progress counter to show conversion status.
- **Logging**: Logs successes and failures to separate log files.

## Prerequisites

- **Python 3.x** installed on your system.
- The `sigma` CLI tool must be installed and available in your PATH (or you can specify its location using the `--sigma-cmd` argument).

## Usage

Run the script with the required arguments:

```bash
python3 convert_sigma_to_kibana_siem.py --source-dir <PATH_TO_SIGMA_RULES> --output-dir <OUTPUT_DIRECTORY> --log-dir <LOG_DIRECTORY>
