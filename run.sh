#!/bin/bash

# Define fixed parameters
NODE_COUNTS=(1 2 4 8 16 32 64 128 256 512)
NTASKS_PER_NODE=4
TIME_LIMIT="00:10:00"

# Default user environment
DEFAULT_UENV="nccl-tests/nccl-2.23.4-1-aws-1.9.2:v0"
#DEFAULT_UENV="nccl-tests/nccl-2.23.4-1-aws-1.13.0:v0"
UENV="$DEFAULT_UENV"

# Default launcher script
DEFAULT_LAUNCHER="./launch"
LAUNCHER="$DEFAULT_LAUNCHER"

# Default environment variables
declare -A DEFAULT_ENV_VARS=(
    [CUDA_CACHE_DISABLE]=1
    [MPICH_NO_BUFFER_ALIAS_CHECK]=1
    [MPICH_OFI_STARTUP_CONNECT]=1
    [MPICH_SMP_SINGLE_COPY_MODE]=NONE
    [MPICH_GPU_SUPPORT_ENABLED]=0
    [MPICH_OFI_CXI_COUNTER_REPORT]=2
    [MPICH_COLL_OPT_OFF]=mpi_allgather
    [NCCL_CROSS_NIC]=0
    [NCCL_NET_GDR_LEVEL]=PHB
    [NCCL_NET]="AWS Libfabric"
    [FI_CXI_DISABLE_HOST_REGISTER]=1
    [FI_MR_CACHE_MONITOR]=userfaultfd
    [FI_CXI_RX_MATCH_MODE]=software
    [FI_HMEM_CUDA_USE_GDRCOPY]=1
    [NCCL_TESTS_DEVICE]=0
)

# Initialize an empty associative array
declare -A ENV_VARS
# Copy default values from DEFAULT_ENV_VARS
for key in "${!DEFAULT_ENV_VARS[@]}"; do
    ENV_VARS["$key"]="${DEFAULT_ENV_VARS[$key]}"
done

# Parse command-line arguments for environment variable overrides
while [[ $# -gt 0 ]]; do
    case "$1" in
        --launcher=*)  # Handle launcher script parameter first
            LAUNCHER="${1#*=}"
            ;;
        *=*)  # Handle key=value pairs as environment variables
            VAR_NAME="${1%%=*}"
            VAR_VALUE="${1#*=}"
            ENV_VARS[$VAR_NAME]=$VAR_VALUE
            ;;
        *)  # If it's not key=value, assume it's UENV
            UENV=$1
            ;;
    esac
    shift
done

# Identify environment variable overrides
declare -A ENV_DIFFS
for VAR in "${!ENV_VARS[@]}"; do
    if [[ "${ENV_VARS[$VAR]}" != "${DEFAULT_ENV_VARS[$VAR]}" ]]; then
        ENV_DIFFS[$VAR]="${ENV_VARS[$VAR]}"
    fi
done

# Generate an identifier for changes
ENV_ID=""
for VAR in "${!ENV_DIFFS[@]}"; do
    ENV_ID+="${VAR}=${ENV_DIFFS[$VAR]}_"
done

# Extract just the base name of the launcher script
LAUNCHER_BASENAME=$(basename "$LAUNCHER")

# Combine identifiers
if [[ "$LAUNCHER" != "$DEFAULT_LAUNCHER" ]]; then
    IDENTIFIER_0="${ENV_ID}${LAUNCHER_BASENAME}_${UENV}"
else
    IDENTIFIER_0="${ENV_ID}${UENV}"
fi
#IDENTIFIER_0="${ENV_ID}${UENV}"
IDENTIFIER="${IDENTIFIER_0//\//_}"  # Replace '/' with '_' for safe naming
IDENTIFIER="${IDENTIFIER//\:/-}"    # Replace ':' with '-' for safe naming
IDENTIFIER="${IDENTIFIER//\=/_}"    # Replace '=' with '_' for safe naming

# Get launcher script path
LAUNCHER=$(realpath ${LAUNCHER})

# Get post processing parser
PARSER=$(realpath ./parse_output.sh)

# Define CPU mask
CPUS_PER_TASK=$(( 288 / NTASKS_PER_NODE ))
CPUBIND="verbose,mask_cpu:"
CPU_MASKS=(
    "0xffffffffffffffffff"
    ",0xffffffffffffffffff000000000000000000"
    ",0xffffffffffffffffff000000000000000000000000000000000000"
    ",0xffffffffffffffffff000000000000000000000000000000000000000000000000000000"
)
for (( i=0; i<$NTASKS_PER_NODE && i<4; i++ )); do
    CPUBIND+="${CPU_MASKS[i]}"
done

# Define result directory
RESULT_DIR="./results/${IDENTIFIER}"
mkdir -p "$RESULT_DIR"

# Store the identifier in a file for easy parsing later
echo "$IDENTIFIER_0" > "${RESULT_DIR}/identifier.txt"

# create a postprocessing script
echo "#!/bin/bash" > "${RESULT_DIR}/postprocess.sh"
chmod +x "${RESULT_DIR}/postprocess.sh"

# Function to decide whether to quote a value
quote_if_needed() {
    local VALUE="$1"
    if [[ "$VALUE" =~ [[:space:]] || "$VALUE" == *\"* || "$VALUE" == *\'* ]]; then
        printf '"%s"' "$VALUE"  # Add quotes if value contains spaces or special characters
    else
        printf '%s' "$VALUE"  # No quotes if it's a simple value
    fi
}

# Loop over NODE_COUNTS
for NODES in "${NODE_COUNTS[@]}"; do
    # Compute total tasks
    NTASKS=$(( NODES * NTASKS_PER_NODE ))

    # Output file naming
    NODES_STR=$(printf "%04d" "$NODES")
    NTASKS_STR=$(printf "%05d" "$NTASKS")
    POSTFIX="n-${NTASKS_STR}-N-${NODES_STR}"
    PREFIX="${RESULT_DIR}/job-${POSTFIX}"

    JOB_SCRIPT="${PREFIX}.sh"
    cat <<EOT > "${JOB_SCRIPT}"
#!/bin/bash

#SBATCH --job-name nccl-tests
#SBATCH --output=${PREFIX}-%j.out
#SBATCH --time=${TIME_LIMIT}
#SBATCH --nodes=${NODES}
#SBATCH --ntasks-per-node=${NTASKS_PER_NODE}
#SBATCH --cpus-per-task=${CPUS_PER_TASK}
#SBATCH --exclusive
#SBATCH --no-requeue
#SBATCH --account=a-csstaff
#SBATCH --uenv=${UENV}:/user-environment
#SBATCH --view=default

set -x

# Set environment variables
EOT


    for VAR in "${!ENV_VARS[@]}"; do
        #echo "export $VAR=${ENV_VARS[$VAR]}" >> "${JOB_SCRIPT}"
        #printf 'export %s="%s"\n' "$VAR" "${ENV_VARS[$VAR]}" >> "$JOB_SCRIPT"
        printf 'export %s=%s\n' "$VAR" "$(quote_if_needed "${ENV_VARS[$VAR]}")" >> "$JOB_SCRIPT"
    done

    # Append the job execution command
    cat <<EOT >> "${JOB_SCRIPT}"

# Launch executable
http_proxy=http://proxy.cscs.ch:8080 https_proxy=https://proxy.cscs.ch:8080 \\
srun -l \\
    --cpu-bind=${CPUBIND} \\
    ${LAUNCHER} \\
    all_reduce_perf -b 8 -e 4294967296 -f 2 -w 8 -n 24
EOT

    # Submit job and capture job ID
    chmod +x "${JOB_SCRIPT}"
    JOB_ID=$(sbatch "${JOB_SCRIPT}" | awk '{print $NF}')
    echo "Job submitted with ID $JOB_ID"

    # Add to postprocessing script
    printf '%s "%s" "%s"\n' "${PARSER}" "./job-${POSTFIX}-${JOB_ID}.out" "./job-${POSTFIX}" >> "${RESULT_DIR}/postprocess.sh"

done
