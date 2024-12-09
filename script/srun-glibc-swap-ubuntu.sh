srun --ntasks-per-node 4 -N 2  podman-hpc run --rm  --mpi \
-v $SCRATCH:/scratch \
ghcr.io/dingp/ubuntu:16.04-mpich \
/scratch/host_lib64/ld-linux-x86-64.so.2 \
--library-path /scratch/host_lib64:/opt/udiImage/modules/mpich:/opt/udiImage/modules/mpich/dep \
/app/check-mpi

