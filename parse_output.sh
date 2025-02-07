#!/bin/bash

LOG_FILE="${1}"
PREFIX="${2}"

# Extract the first table (Performance Data)
awk '
    /^[[:space:]]*0: #       size/ {flag=1; print; next}   # Capture header
    flag && /^[[:space:]]*0: # Out of bounds values/ {flag=0}   # Stop capturing at "Out of bounds values"
    flag { print }
' "${LOG_FILE}" | awk '
    NR<=2 {sub(/^[[:space:]]*0: #/, " "); print}
    NR>2 {sub(/^[[:space:]]*0: /, ""); print}
' > "${PREFIX}.txt"
awk 'NR==1 || NR>2' "${PREFIX}.txt" | sed -E 's/^ +//' | sed -E 's/ +/,/g' > "${PREFIX}.csv"

# Extract Network Timeouts
NETWORK_TIMEOUTS=$(grep -oP 'MPICH Slingshot Network Summary: \K[0-9]+' "$LOG_FILE")

echo "Extracted Performance Table (Saved to ${PREFIX}.txt)"
echo "Network Timeouts: $NETWORK_TIMEOUTS"
