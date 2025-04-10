#!/bin/bash
# Sigma to Kibana Detection Rules Converter
#
# This script converts Sigma rules to Kibana detection rules in EQL format
# It handles errors gracefully and logs successful and failed conversions
#
# Usage: ./convert_sigma.sh [options]
#
# Options:
#   -s, --source DIR      Source directory containing Sigma rules (default: ./rules)
#   -o, --output DIR      Output directory for converted rules (default: ./converted_rules)
#   -l, --logs DIR        Directory for logs (default: ./conversion_logs)
#   -t, --target TYPE     Target query type: eql, lucene, esql (default: eql)
#   -f, --format FORMAT   Output format (default: siem_rule_ndjson)
#   -p, --pipeline NAME   Pipeline to use (default: ecs_windows)
#   -h, --help            Display this help message and exit
#
# Examples:
#   ./convert_sigma.sh --source ~/sigma/rules/windows --output ~/kibana_rules
#   ./convert_sigma.sh -s ./my_rules -t lucene -p my_custom_pipeline
#
# Prerequisites:
#   - sigma-cli must be installed: pip3 install sigma-cli
#   - Elasticsearch backend must be installed: sigma plugin install elasticsearch
#
# Setup:
#   1. Save this script as convert_sigma.sh
#   2. Make it executable: chmod +x convert_sigma.sh
#   3. Run it with appropriate options
#   4. Import the resulting all_kibana_rules.ndjson into Kibana Security
#
# Notes on Common Issues:
#   - Some rules using fieldref feature (e.g., TargetFilename|fieldref: Image) will fail
#     with "ES Lucene backend can't handle field references" error
#   - These must be manually converted or modified to work with Kibana
#   - Using --target eql may help with some field reference issues
#
# Default values
SOURCE_DIR="./rules"
OUTPUT_DIR="./converted_rules"
LOG_DIR="./conversion_logs"
TARGET="eql"
FORMAT="siem_rule_ndjson"
PIPELINE="ecs_windows"

# Display help message
show_help() {
  echo "Usage: $0 [options]"
  echo "Convert Sigma rules to Kibana detection rules"
  echo ""
  echo "Options:"
  echo "  -s, --source DIR      Source directory containing Sigma rules (default: ./rules)"
  echo "  -o, --output DIR      Output directory for converted rules (default: ./converted_rules)"
  echo "  -l, --logs DIR        Directory for logs (default: ./conversion_logs)"
  echo "  -t, --target TYPE     Target query type: eql, lucene, esql (default: eql)"
  echo "  -f, --format FORMAT   Output format (default: siem_rule_ndjson)"
  echo "  -p, --pipeline NAME   Pipeline to use (default: ecs_windows)"
  echo "  -h, --help            Display this help message and exit"
  echo ""
  echo "Example: $0 --source ~/sigma/rules/windows --output ~/kibana_rules"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -s|--source)
      SOURCE_DIR="$2"
      shift 2
      ;;
    -o|--output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -l|--logs)
      LOG_DIR="$2"
      shift 2
      ;;
    -t|--target)
      TARGET="$2"
      shift 2
      ;;
    -f|--format)
      FORMAT="$2"
      shift 2
      ;;
    -p|--pipeline)
      PIPELINE="$2"
      shift 2
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      show_help
      exit 1
      ;;
  esac
done

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
  echo "Error: Source directory '$SOURCE_DIR' does not exist!"
  exit 1
fi

# Create directories if they don't exist
mkdir -p "$OUTPUT_DIR"
mkdir -p "$LOG_DIR"

# Log files
SUCCESS_LOG="$LOG_DIR/successful_conversions.log"
FAILURE_LOG="$LOG_DIR/failed_conversions.log"

# Initialize logs
echo "Sigma rule conversion started at $(date)" > "$SUCCESS_LOG"
echo "Sigma rule conversion started at $(date)" > "$FAILURE_LOG"

# Counter variables
total=0
success=0
failed=0

# Process each YAML file
for file in $(find "$SOURCE_DIR" -name "*.yml"); do
  ((total++))
  filename=$(basename "$file")
  output_file="$OUTPUT_DIR/${filename%.yml}.ndjson"
  
  echo "Converting $filename..."
  
  # Attempt conversion
  if sigma convert --target "$TARGET" --format "$FORMAT" --pipeline "$PIPELINE" "$file" > "$output_file" 2>"$LOG_DIR/temp_error.log"; then
    ((success++))
    echo "SUCCESS: $file" >> "$SUCCESS_LOG"
  else
    ((failed++))
    error=$(cat "$LOG_DIR/temp_error.log")
    echo "FAILED: $file - Error: $error" >> "$FAILURE_LOG"
    # Remove empty output file if conversion failed
    rm -f "$output_file"
  fi
done

# Combine all successful conversions into one file
if [ $success -gt 0 ]; then
  cat "$OUTPUT_DIR"/*.ndjson > "$OUTPUT_DIR/all_kibana_rules.ndjson"
  echo "Combined all successful conversions into all_kibana_rules.ndjson"
fi

# Summary
echo "Conversion complete!"
echo "Total rules processed: $total"
echo "Successfully converted: $success"
echo "Failed conversions: $failed"
echo "See logs in $LOG_DIR for details"
