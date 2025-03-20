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

    ./run.sh NCCL_IGNORE_CPU_AFFINITY=1 nccl-tests/nccl-2.26.2-1-aws-1.13.0:v0 --launcher=launch_with_fixed_hsn

This will run the benchmarks with the `NCCL_IGNORE_CPU_AFFINITY` environment
variable set to `1` and the `nccl-tests/nccl-2.26.2-1-aws-1.13.0:v0` uenv, and
will use the `launch_with_fixed_hsn` launch script.

The script will create a directory `results` in the current working directory
and write the output of the jobs there. Under the results directory, it will
create a subdirectory for the particular configuration according to the
environment variables, uenv and launch script, where the output of the jobs
will be stored. In order to gather statistics from multiple runs, a new
`run_xxxx` directory will be created for each run. For example, the directory
structure could look like this

    results
    ├── launch_with_fixed_hsn_nccl-tests_nccl-2.26.2-1-aws-1.9.2-v0
    │   ├── identifier.txt
    │   ├── run_0000
    │   ├── run_0001
    │   └── run_0002
    ├── NCCL_CROSS_NIC_1_launch_with_fixed_hsn_nccl-tests_nccl-2.26.2-1-aws-1.9.2-v0
    │   ├── identifier.txt
    │   ├── run_0000
    │   ├── run_0001
    │   └── run_0002
    :

where each run directory will contain the submission scripts and a post-processing
script:

    results
    :
    ├── NCCL_CROSS_NIC_2_nccl-tests_nccl-2.23.4-1-aws-1.9.2-v0
    │   ├── identifier.txt
    │   └── run_0000
    │       ├── job-n-00004-N-0001.sh
    │       ├── job-n-00008-N-0002.sh
    │       ├── job-n-00016-N-0004.sh
    │       ├── job-n-00032-N-0008.sh
    │       ├── job-n-00064-N-0016.sh
    │       ├── job-n-00128-N-0032.sh
    │       ├── job-n-00256-N-0064.sh
    │       ├── job-n-00512-N-0128.sh
    │       ├── job-n-01024-N-0256.sh
    │       └── job-n-02048-N-0512.sh
    :

After the jobs have finished, you can run the `postprocess.sh` script in the
top level directory to generate a summary of the results which can the later be
used to generate plots with the `plot_results.py` script.
Eventually, you will find the following files and directories in the results directories:

    results
    :
    ├── NCCL_CROSS_NIC_2_nccl-tests_nccl-2.23.4-1-aws-1.9.2-v0
    │   ├── identifier.txt
    │   └── run_0000
    :       :
    │       ├── job-n-01024-N-0256-258883-logs
    │       │   ├── bench.log
    │       │   ├── nccl-debug
    │       │   ├── std.err
    │       │   └── std.out
    │       ├── job-n-01024-N-0256.csv
    │       ├── job-n-01024-N-0256.sh
    │       ├── job-n-01024-N-0256.txt
    :       :

i.e., for each job, there will be a directory containing

- job script: `job-n-xxxxx-N-yyyy.sh`
- log files: `job-n-xxxxx-N-yyyy-zzzzzz-logs`
    - benchmark results: `bench.log`
    - nccl debug info: `nccl-debug`
    - standard error: `std.err`
    - standard output: `std.out`
- benchmark result table: `job-n-xxxxx-N-yyyy.txt`
- benchmark result table: `job-n-xxxxx-N-yyyy.csv`


The default environment variables are set in the `run.sh` script:

    CUDA_CACHE_DISABLE=1
    MPICH_NO_BUFFER_ALIAS_CHECK=1
    MPICH_OFI_STARTUP_CONNECT=1
    MPICH_SMP_SINGLE_COPY_MODE=NONE
    MPICH_GPU_SUPPORT_ENABLED=0
    MPICH_OFI_CXI_COUNTER_REPORT=2
    MPICH_COLL_OPT_OFF=mpi_allgather
    NCCL_CROSS_NIC=0
    NCCL_NET_GDR_LEVEL=PHB
    NCCL_NET="AWS Libfabric"
    NCCL_DEBUG=INFO
    FI_LOG_LEVEL="INFO"
    FI_CXI_DISABLE_HOST_REGISTER=1
    FI_MR_CACHE_MONITOR=userfaultfd
    FI_CXI_RX_MATCH_MODE=software
    FI_HMEM_CUDA_USE_GDRCOPY=1
    NCCL_TESTS_DEVICE=0


The default launch script is [launch](launch) which sets the visible GPU according to
the local `slurm rank` and restricts `nccl` to use the slingshot high-speed
network.

Furthermore, all benchmarks are launched with the `slurm` option


    --network=disable_rdzv_get


## Results

Results are plotted for different message sizes. The legends indicate the
difference with respect to the default environment variables. The `nccl`
version is fixed at `2.26.2-1` while there are two versions of the
`aws-ofi-plugin`: `1.9.2` and `1.13.0`. The number of runs is indicated above
the bars. The hatched bars indicate that the sanity check has failed for at
least one run and wrong results were obtained. The number of failed runs is
indicated at the bottom of the bars.

### All2All (28 nodes/ 2 chassis)

![busbw for message size =  1792        ](plots_nccl_debug_all2all/busbw_vs_nodes_1792.svg)
![busbw for message size =  3584        ](plots_nccl_debug_all2all/busbw_vs_nodes_3584.svg)
![busbw for message size =  7168        ](plots_nccl_debug_all2all/busbw_vs_nodes_7168.svg)
![busbw for message size =  16128       ](plots_nccl_debug_all2all/busbw_vs_nodes_16128.svg)
![busbw for message size =  32256       ](plots_nccl_debug_all2all/busbw_vs_nodes_32256.svg)
![busbw for message size =  64512       ](plots_nccl_debug_all2all/busbw_vs_nodes_64512.svg)
![busbw for message size =  523264      ](plots_nccl_debug_all2all/busbw_vs_nodes_523264.svg)
![busbw for message size =  130816      ](plots_nccl_debug_all2all/busbw_vs_nodes_130816.svg)
![busbw for message size =  261632      ](plots_nccl_debug_all2all/busbw_vs_nodes_261632.svg)
![busbw for message size =  1048320     ](plots_nccl_debug_all2all/busbw_vs_nodes_1048320.svg)
![busbw for message size =  2096640     ](plots_nccl_debug_all2all/busbw_vs_nodes_2096640.svg)
![busbw for message size =  4193280     ](plots_nccl_debug_all2all/busbw_vs_nodes_4193280.svg)
![busbw for message size =  8388352     ](plots_nccl_debug_all2all/busbw_vs_nodes_8388352.svg)
![busbw for message size =  16776704    ](plots_nccl_debug_all2all/busbw_vs_nodes_16776704.svg)
![busbw for message size =  33553408    ](plots_nccl_debug_all2all/busbw_vs_nodes_33553408.svg)
![busbw for message size =  67108608    ](plots_nccl_debug_all2all/busbw_vs_nodes_67108608.svg)
![busbw for message size =  134217216   ](plots_nccl_debug_all2all/busbw_vs_nodes_134217216.svg)
![busbw for message size =  268434432   ](plots_nccl_debug_all2all/busbw_vs_nodes_268434432.svg)
![busbw for message size =  536870656   ](plots_nccl_debug_all2all/busbw_vs_nodes_536870656.svg)
![busbw for message size =  1073741312  ](plots_nccl_debug_all2all/busbw_vs_nodes_1073741312.svg)
![busbw for message size =  2147482624  ](plots_nccl_debug_all2all/busbw_vs_nodes_2147482624.svg)
![busbw for message size =  4294967040  ](plots_nccl_debug_all2all/busbw_vs_nodes_4294967040.svg)


### All2All (14 nodes/ 1 chassis)

![busbw for message size =  1792        ](plots_nccl_debug_all2all_14/busbw_vs_nodes_1792.svg)
![busbw for message size =  3584        ](plots_nccl_debug_all2all_14/busbw_vs_nodes_3584.svg)
![busbw for message size =  7168        ](plots_nccl_debug_all2all_14/busbw_vs_nodes_7168.svg)
![busbw for message size =  16128       ](plots_nccl_debug_all2all_14/busbw_vs_nodes_16128.svg)
![busbw for message size =  32256       ](plots_nccl_debug_all2all_14/busbw_vs_nodes_32256.svg)
![busbw for message size =  64512       ](plots_nccl_debug_all2all_14/busbw_vs_nodes_64512.svg)
![busbw for message size =  523264      ](plots_nccl_debug_all2all_14/busbw_vs_nodes_523264.svg)
![busbw for message size =  130816      ](plots_nccl_debug_all2all_14/busbw_vs_nodes_130816.svg)
![busbw for message size =  261632      ](plots_nccl_debug_all2all_14/busbw_vs_nodes_261632.svg)
![busbw for message size =  1048320     ](plots_nccl_debug_all2all_14/busbw_vs_nodes_1048320.svg)
![busbw for message size =  2096640     ](plots_nccl_debug_all2all_14/busbw_vs_nodes_2096640.svg)
![busbw for message size =  4193280     ](plots_nccl_debug_all2all_14/busbw_vs_nodes_4193280.svg)
![busbw for message size =  8388352     ](plots_nccl_debug_all2all_14/busbw_vs_nodes_8388352.svg)
![busbw for message size =  16776704    ](plots_nccl_debug_all2all_14/busbw_vs_nodes_16776704.svg)
![busbw for message size =  33553408    ](plots_nccl_debug_all2all_14/busbw_vs_nodes_33553408.svg)
![busbw for message size =  67108608    ](plots_nccl_debug_all2all_14/busbw_vs_nodes_67108608.svg)
![busbw for message size =  134217216   ](plots_nccl_debug_all2all_14/busbw_vs_nodes_134217216.svg)
![busbw for message size =  268434432   ](plots_nccl_debug_all2all_14/busbw_vs_nodes_268434432.svg)
![busbw for message size =  536870656   ](plots_nccl_debug_all2all_14/busbw_vs_nodes_536870656.svg)
![busbw for message size =  1073741312  ](plots_nccl_debug_all2all_14/busbw_vs_nodes_1073741312.svg)
![busbw for message size =  2147482624  ](plots_nccl_debug_all2all_14/busbw_vs_nodes_2147482624.svg)
![busbw for message size =  4294967040  ](plots_nccl_debug_all2all_14/busbw_vs_nodes_4294967040.svg)


