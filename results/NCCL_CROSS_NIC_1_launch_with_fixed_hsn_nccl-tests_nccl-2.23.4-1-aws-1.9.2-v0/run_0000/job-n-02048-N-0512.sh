#!/bin/bash

#SBATCH --job-name nccl-tests
#SBATCH --output=./results/NCCL_CROSS_NIC_1_launch_with_fixed_hsn_nccl-tests_nccl-2.23.4-1-aws-1.9.2-v0/job-n-02048-N-0512-%j.out
#SBATCH --time=00:10:00
#SBATCH --nodes=512
#SBATCH --ntasks-per-node=4
#SBATCH --cpus-per-task=72
#SBATCH --exclusive
#SBATCH --no-requeue
#SBATCH --account=a-csstaff
#SBATCH --uenv=nccl-tests/nccl-2.23.4-1-aws-1.9.2:v0:/user-environment
#SBATCH --view=default

set -x

# Set environment variables
export MPICH_NO_BUFFER_ALIAS_CHECK=1
export MPICH_GPU_SUPPORT_ENABLED=0
export NCCL_NET="AWS Libfabric"
export MPICH_OFI_STARTUP_CONNECT=1
export NCCL_TESTS_DEVICE=0
export FI_CXI_DISABLE_HOST_REGISTER=1
export FI_HMEM_CUDA_USE_GDRCOPY=1
export FI_CXI_RX_MATCH_MODE=software
export NCCL_NET_GDR_LEVEL=PHB
export CUDA_CACHE_DISABLE=1
export MPICH_OFI_CXI_COUNTER_REPORT=2
export MPICH_COLL_OPT_OFF=mpi_allgather
export FI_MR_CACHE_MONITOR=userfaultfd
export MPICH_SMP_SINGLE_COPY_MODE=NONE
export NCCL_CROSS_NIC=1

# Launch executable
http_proxy=http://proxy.cscs.ch:8080 https_proxy=https://proxy.cscs.ch:8080 \
srun -l \
    --cpu-bind=verbose,mask_cpu:0xffffffffffffffffff,0xffffffffffffffffff000000000000000000,0xffffffffffffffffff000000000000000000000000000000000000,0xffffffffffffffffff000000000000000000000000000000000000000000000000000000 \
    /iopsstor/scratch/cscs/boeschf/nccl-testing-new/launch_with_fixed_hsn \
    all_reduce_perf -b 8 -e 4294967296 -f 2 -w 8 -n 24
