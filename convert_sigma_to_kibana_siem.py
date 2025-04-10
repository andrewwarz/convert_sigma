import os
import json
import argparse
import subprocess
import sys

REMOVE_FIELDS = [
    "consumer", "throttle", "schedule", "notify_when", "rule_type_id",
    "filters", "outputIndex", "relatedIntegrations", "requiredFields",
    "meta", "license", "setup"
]

RENAME_FIELDS = {
    "ruleId": "rule_id",
    "riskScore": "risk_score",
    "falsePositives": "false_positives",
    "exceptionsList": "exceptions_list"
}

def clean_rule(raw_rule):
    cleaned = {}

    # Flatten params to top-level
    params = raw_rule.pop("params", {})
    for key, value in params.items():
        cleaned_key = RENAME_FIELDS.get(key, key)
        cleaned[cleaned_key] = value

    # Merge remaining allowed top-level fields
    for key, value in raw_rule.items():
        if key not in REMOVE_FIELDS:
            cleaned[key] = value

    # Remove negated index patterns
    if "index" in cleaned:
        cleaned["index"] = [i for i in cleaned["index"] if not i.startswith("-")]

    # Set required defaults if missing
    cleaned.setdefault("version", 1)
    cleaned.setdefault("enabled", True)
    cleaned.setdefault("actions", [])
    cleaned.setdefault("tags", [])
    cleaned.setdefault("threat", [])
    cleaned.setdefault("false_positives", [])
    cleaned.setdefault("exceptions_list", [])
    cleaned.setdefault("immutable", False)

    return cleaned

def find_sigma_files(source_dir):
    sigma_files = []
    for root, _, files in os.walk(source_dir):
        for file in files:
            if file.endswith(".yml") or file.endswith(".yaml"):
                sigma_files.append(os.path.join(root, file))
    return sigma_files

def process_sigma_rules(source_dir, output_dir, log_dir, sigma_cmd, target, pipeline):
    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(log_dir, exist_ok=True)

    success_log = os.path.join(log_dir, "successful_conversions.log")
    fail_log = os.path.join(log_dir, "failed_conversions.log")
    combined_rules = []

    sigma_files = find_sigma_files(source_dir)
    total = len(sigma_files)
    success = failed = 0

    with open(success_log, "w") as slog, open(fail_log, "w") as flog:
        for idx, file_path in enumerate(sigma_files, start=1):
            # Print simple progress update
            sys.stdout.write(f"\rProcessing file {idx} of {total}")
            sys.stdout.flush()

            output_filename = os.path.basename(file_path).replace(".yml", ".ndjson").replace(".yaml", ".ndjson")
            output_path = os.path.join(output_dir, output_filename)
            try:
                result = subprocess.run(
                    [sigma_cmd, "convert", "--target", target, "--format", "siem_rule", "--pipeline", pipeline, file_path],
                    capture_output=True,
                    text=True,
                    check=True
                )
                raw_rule = json.loads(result.stdout)
                cleaned = clean_rule(raw_rule)
                ndjson_line = json.dumps(cleaned)

                with open(output_path, "w") as outf:
                    outf.write(ndjson_line + "\n")
                combined_rules.append(ndjson_line)

                slog.write(f"SUCCESS: {file_path}\n")
                success += 1
            except subprocess.CalledProcessError as e:
                flog.write(f"FAILED: {file_path} - sigma convert error: {e.stderr}\n")
                failed += 1
            except Exception as e:
                flog.write(f"FAILED: {file_path} - JSON error: {e}\n")
                failed += 1

    # Finish progress line
    print()

    combined_path = os.path.join(output_dir, "all_kibana_rules.ndjson")
    with open(combined_path, "w") as combined:
        combined.write("\n".join(combined_rules))

    print(f"\n✅ Conversion complete!")
    print(f"Total: {total}, Success: {success}, Failed: {failed}")
    print(f"Combined NDJSON file: {combined_path}")
    print(f"Logs: {success_log}, {fail_log}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert Sigma YAML rules to Kibana-compatible NDJSON")
    parser.add_argument("--source-dir", required=True, help="Directory with Sigma YAML rules")
    parser.add_argument("--output-dir", required=True, help="Directory for NDJSON output")
    parser.add_argument("--log-dir", required=True, help="Directory for logs")
    parser.add_argument("--sigma-cmd", default="sigma", help="Path to `sigma` CLI")
    parser.add_argument("--target", default="lucene", help="Target format (default: lucene)")
    parser.add_argument("--pipeline", default="ecs_windows", help="Sigma pipeline to use (default: ecs_windows)")
    args = parser.parse_args()

    process_sigma_rules(
        source_dir=args.source_dir,
        output_dir=args.output_dir,
        log_dir=args.log_dir,
        sigma_cmd=args.sigma_cmd,
        target=args.target,
        pipeline=args.pipeline
    )
