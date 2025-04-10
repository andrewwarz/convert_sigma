#!/bin/bash

# Display help message
show_help() {
  echo "Usage: $0 -s SOURCE_DIR -o OUTPUT_DIR -l LOG_DIR [-t TARGET] [-f FORMAT] [-p PIPELINE]"
  echo "Convert Sigma rules to Kibana detection rules"
  echo ""
  echo "Required options:"
  echo "  -s, --source DIR      Source directory containing Sigma rules"
  echo "  -o, --output DIR      Output directory for converted rules"
  echo "  -l, --logs DIR        Directory for logs"
  echo ""
  echo "Optional options:"
  echo "  -t, --target TYPE     Target query type: eql, lucene, esql (default: eql)"
  echo "  -f, --format FORMAT   Output format (default: siem_rule_ndjson)"
  echo "  -p, --pipeline NAME   Pipeline to use (default: ecs_windows)"
  echo "  -h, --help            Display this help message and exit"
  echo ""
  echo "Example: $0 -s /home/user/sigma/rules/windows -o /home/user/converted_rules -l /home/user/logs"
}

# Initialize variables
SOURCE_DIR=""
OUTPUT_DIR=""
LOG_DIR=""
TARGET="eql"
FORMAT="siem_rule_ndjson"
PIPELINE="ecs_windows"

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

# Check required parameters
if [ -z "$SOURCE_DIR" ] || [ -z "$OUTPUT_DIR" ] || [ -z "$LOG_DIR" ]; then
  echo "Error: Missing required parameters!"
  show_help
  exit 1
fi

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
