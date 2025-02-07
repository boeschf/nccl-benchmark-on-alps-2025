# NCCL-Benchmarks on Alps

This a little project that helps set up the
[nccl-tests](https://github.com/NVIDIA/nccl-tests) on Alps using custom
**uenv**s and running a bunch of **allgather** benchmarks with different configurations.

## Build Instructions

### Creating the uenv

The recipe for the **uenv** is located in `uenv-recipe`. You will need
[stackinator](https://github.com/eth-cscs/stackinator), see the
[docs](https://eth-cscs.github.io/stackinator/configuring/) for information on
how to configure and build the stack. The recipe needs to be specialized for
the intended vCluster, so you'll also need
[alps-cluster-config](https://github.com/eth-cscs/alps-cluster-config).

The process should look roughly like this:

1. Allocate a compute node for building

        salloc -N 1 --time=05:00:00 --account <my-account>

2. Run interactively once the allocation has been granted

        srun --nodes=1 --pty bash -i

3. Go to the recipe folder and configure the stack

        cd uenv-recipe
        /path/to/stackinator/bin/stack-config \
            -c /path/to/cache-config.yaml \
            -b /dev/shm/$USER/stack-build \
            -s /path/to/alps-cluster-config/todi \
            -m /user-environment \
            -r . \
            --develop
        cd /dev/shm/$USER/stack-build
        env --ignore-environment http_proxy="$http_proxy" https_proxy="$https_proxy" no_proxy="$no_proxy" PATH=/usr/bin:/bin:`pwd`/spack/bin HOME=$HOME make store.squashfs -j200

4. Add the stack to the uenv repository

        uenv image add nccl-tests/<desc>:v<x>@clariden%gh200 /dev/shm/$USER/stack-build/store.squashfs

5. Quit the interactive session


## Run Instructions

The `run.sh` script launches a range of jobs. It takes as arguments changes to
the environment variables, as well as the particular uenv to use. The script is
intended to be run on the login node. An example invocation would be:

    ./run.sh NCCL_IGNORE_CPU_AFFINITY=1 nccl-tests/nccl-2.23.4-1-aws-1.13.0:v0

This will run the benchmarks with the `NCCL_IGNORE_CPU_AFFINITY` environment
variable set to `1` and the `nccl-tests/nccl-2.23.4-1-aws-1.13.0:v0` uenv.

The script will create a directory `results` in the current working directory
and write the output of the jobs there. Under the results directory, it will
create a subdirectory for the particular configuration according to the
environment variables and uenv, where the output of the jobs will be stored.
After the jobs have finished, you can run the `postprocess.sh` script in the
subdirectory to generate a summary of the results which can the later be used
to generate plots with the `plot_results.py` script.

The default environment variables are set in the `run.sh` script:

    
    CUDA_CACHE_DISABLE=1
    MPICH_NO_BUFFER_ALIAS_CHECK=1
    MPICH_OFI_STARTUP_CONNECT=1
    MPICH_SMP_SINGLE_COPY_MODE=NONE
    MPICH_GPU_SUPPORT_ENABLED=0
    MPICH_OFI_CXI_COUNTER_REPORT=2
    MPICH_COLL_OPT_OFF]=mpi_allgather
    NCCL_CROSS_NIC=0
    NCCL_NET_GDR_LEVEL=PHB
    NCCL_NET]="AWS Libfabric"
    FI_CXI_DISABLE_HOST_REGISTER=1
    FI_MR_CACHE_MONITOR=userfaultfd
    FI_CXI_RX_MATCH_MODE=software
    FI_HMEM_CUDA_USE_GDRCOPY=1
    NCCL_TESTS_DEVICE=0

## Results

Results are plotted for different message sizes. The legends indicate the difference with respect to the default environment variables.
The `nccl` version is fixed at `2.23.4-1` while there are two versions of the `aws-ofi-plugin`: `1.9.2` and `1.13.0`. The hatched bars
indicate that the sanity check has failed and wrong results were received.

![busbw for message size =  512        ](plots/busbw_vs_nodes_512.svg)
![busbw for message size =  1024       ](plots/busbw_vs_nodes_1024.svg)
![busbw for message size =  2048       ](plots/busbw_vs_nodes_2048.svg)
![busbw for message size =  4096       ](plots/busbw_vs_nodes_4096.svg)
![busbw for message size =  8192       ](plots/busbw_vs_nodes_8192.svg)
![busbw for message size =  16384      ](plots/busbw_vs_nodes_16384.svg)
![busbw for message size =  32768      ](plots/busbw_vs_nodes_32768.svg)
![busbw for message size =  65536      ](plots/busbw_vs_nodes_65536.svg)
![busbw for message size =  131072     ](plots/busbw_vs_nodes_131072.svg)
![busbw for message size =  262144     ](plots/busbw_vs_nodes_262144.svg)
![busbw for message size =  524288     ](plots/busbw_vs_nodes_524288.svg)
![busbw for message size =  1048576    ](plots/busbw_vs_nodes_1048576.svg)
![busbw for message size =  2097152    ](plots/busbw_vs_nodes_2097152.svg)
![busbw for message size =  4194304    ](plots/busbw_vs_nodes_4194304.svg)
![busbw for message size =  8388608    ](plots/busbw_vs_nodes_8388608.svg)
![busbw for message size =  16777216   ](plots/busbw_vs_nodes_16777216.svg)
![busbw for message size =  33554432   ](plots/busbw_vs_nodes_33554432.svg)
![busbw for message size =  67108864   ](plots/busbw_vs_nodes_67108864.svg)
![busbw for message size =  134217728  ](plots/busbw_vs_nodes_134217728.svg)
![busbw for message size =  268435456  ](plots/busbw_vs_nodes_268435456.svg)
![busbw for message size =  536870912  ](plots/busbw_vs_nodes_536870912.svg)
![busbw for message size =  1073741824 ](plots/busbw_vs_nodes_1073741824.svg)
![busbw for message size =  2147483648 ](plots/busbw_vs_nodes_2147483648.svg)
![busbw for message size =  4294967296 ](plots/busbw_vs_nodes_4294967296.svg)

