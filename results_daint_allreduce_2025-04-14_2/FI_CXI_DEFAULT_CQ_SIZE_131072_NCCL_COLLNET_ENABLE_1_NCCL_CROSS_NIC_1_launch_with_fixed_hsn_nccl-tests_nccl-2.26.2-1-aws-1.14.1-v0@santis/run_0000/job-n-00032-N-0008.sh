#!/bin/bash

#SBATCH --job-name nccl-tests
#SBATCH --output=results_daint_allreduce_2025-04-14_2/FI_CXI_DEFAULT_CQ_SIZE_131072_NCCL_COLLNET_ENABLE_1_NCCL_CROSS_NIC_1_launch_with_fixed_hsn_nccl-tests_nccl-2.26.2-1-aws-1.14.1-v0@santis/run_0000/job-n-00032-N-0008-%j-logs/std.out
#SBATCH --error=results_daint_allreduce_2025-04-14_2/FI_CXI_DEFAULT_CQ_SIZE_131072_NCCL_COLLNET_ENABLE_1_NCCL_CROSS_NIC_1_launch_with_fixed_hsn_nccl-tests_nccl-2.26.2-1-aws-1.14.1-v0@santis/run_0000/job-n-00032-N-0008-%j-logs/std.err
#SBATCH --time=00:10:00
#SBATCH --nodes=8
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=71
#SBATCH --exclusive
#SBATCH --no-requeue
#SBATCH --account=csstaff
#SBATCH --uenv=nccl-tests/nccl-2.26.2-1-aws-1.14.1:v0@santis:/user-environment
#SBATCH --view=default
#SBATCH --network=disable_rdzv_get

set -x

OUT_DATA_DIR="results_daint_allreduce_2025-04-14_2/FI_CXI_DEFAULT_CQ_SIZE_131072_NCCL_COLLNET_ENABLE_1_NCCL_CROSS_NIC_1_launch_with_fixed_hsn_nccl-tests_nccl-2.26.2-1-aws-1.14.1-v0@santis/run_0000/job-n-00032-N-0008-${SLURM_JOB_ID}-logs"
mkdir -p ${OUT_DATA_DIR}

#export OMP_NUM_THREADS=71
#export OMP_PLACES=cores
#export OMP_PROC_BIND=close

# Set environment variables
export MPICH_NO_BUFFER_ALIAS_CHECK=1
export MPICH_GPU_SUPPORT_ENABLED=0
export FI_CXI_DEFAULT_CQ_SIZE=131072
export NCCL_NET="AWS Libfabric"
export FI_LOG_LEVEL=INFO
export MPICH_OFI_STARTUP_CONNECT=1
export NCCL_TESTS_DEVICE=0
export FI_CXI_DISABLE_HOST_REGISTER=1
export FI_HMEM_CUDA_USE_GDRCOPY=1
export FI_CXI_RX_MATCH_MODE=software
export NCCL_COLLNET_ENABLE=1
export NCCL_NET_GDR_LEVEL=PHB
export CUDA_CACHE_DISABLE=1
export MPICH_OFI_CXI_COUNTER_REPORT=2
export MPICH_COLL_OPT_OFF=mpi_allgather
export FI_MR_CACHE_MONITOR=userfaultfd
export MPICH_SMP_SINGLE_COPY_MODE=NONE
export NCCL_CROSS_NIC=1

OUT_DATA="${OUT_DATA_DIR}/bench.log"
#NCCL_DEBUG_DIR="${OUT_DATA_DIR}/nccl-debug"
#mkdir -p "${NCCL_DEBUG_DIR}"
#export NCCL_DEBUG_FILE="${NCCL_DEBUG_DIR}/nccl.%h.%p.log"

# Launch executable
srun -l \
    --cpu-bind=verbose \
    /iopsstor/scratch/cscs/boeschf/nccl-benchmark-on-alps-2025-2/launch_with_fixed_hsn \
    all_reduce_perf -N 10 -b 8 -e 4294967296 -f 2 -w 8 -n 24 > ${OUT_DATA}
