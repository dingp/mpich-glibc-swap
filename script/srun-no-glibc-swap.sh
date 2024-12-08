srun --ntasks-per-node 1 -N 2  podman-hpc run --rm --mpi \
ghcr.io/dingp/fedora:26-mpich \
/app/check-mpi

