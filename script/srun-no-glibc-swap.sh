srun --ntasks-per-node 4 -N 2  podman-hpc run --rm --mpi \
ghcr.io/dingp/fedora:26-mpich \
/app/check-mpi

