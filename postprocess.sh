#!/bin/bash

# Function to parse the output
parse_output() {
    local LOG_FILE="$1"
    local PREFIX="$2"

    # Extract the first table (Performance Data)
    awk '
        /^[[:space:]]*0: #       size/ {flag=1; print; next}   # Capture header
        flag && /^[[:space:]]*0: #        \(B\)/ {print; next}  # Capture second header row
        flag && /^[[:space:]]*0: # Out of bounds values/ {flag=0}   # Stop capturing at "Out of bounds values"
        flag && /^[[:space:]]*0:[[:space:]]+[0-9]/ { print }  # Ensure only valid data rows are captured, allowing variable whitespace
    ' "$LOG_FILE" | awk '
        NR<=2 {sub(/^[[:space:]]*0: #/, " "); print}
        NR>2 {sub(/^[[:space:]]*0: /, ""); print}
    ' > "${PREFIX}.txt"

    awk 'NR==1 || NR>2' "${PREFIX}.txt" | sed -E 's/^ +//' | sed -E 's/ +/,/g' > "${PREFIX}.csv"

    # Extract Network Timeouts
    NETWORK_TIMEOUTS=$(grep -oP 'MPICH Slingshot Network Summary: \K[0-9]+' "$LOG_FILE")

    echo "Extracted Performance Table (Saved to ${PREFIX}.txt)"
    echo "Network Timeouts: $NETWORK_TIMEOUTS"

    #cat "${PREFIX}.txt"
    tail -n 1 "${PREFIX}.txt"
    echo ""
}

# Define the root directory to scan
ROOT_DIR="${1:-./results}"  # Default to current directory if not provided

# Define the pattern for folder matching
PATTERN='job-n-[0-9]+-N-[0-9]+-[0-9]+-logs'

# Find matching directories
find "$ROOT_DIR" -type d -regextype posix-extended -regex ".*/$PATTERN" | sort | while read -r dir; do
    # Extract the full folder name
    folder_name=$(basename "$dir")
    
    # Extract the PREFIX (job-n-xxxxx-N-yyyy)
    #if [[ $folder_name =~ (job-n-[0-9]+-N-[0-9]+)-[0-9]+-logs ]]; then
    #    PREFIX="${dir%/*}/${BASH_REMATCH[1]}"
    if [[ $folder_name =~ job-n-([0-9]+)-N-([0-9]+)-[0-9]+-logs ]]; then
        PREFIX="${dir%/*}/job-n-${BASH_REMATCH[1]}-N-${BASH_REMATCH[2]}"
        NODES=${BASH_REMATCH[2]}
        TASKS=${BASH_REMATCH[1]}
    else
        echo "Skipping invalid folder: $folder_name"
        continue
    fi
    
    # Define the log file path
    LOGFILE="$dir/bench.log"
    
    ## Check if the log file exists
    echo ""
    echo "N = ${NODES}"
    if [[ -f "$LOGFILE" ]]; then
        echo "Processing: $LOGFILE with prefix $PREFIX"
        echo ""
        parse_output "$LOGFILE" "$PREFIX"
    else
        echo "Log file not found: $LOGFILE"
    fi
    echo ""
done

