srun --ntasks-per-node 1 -N 2  podman-hpc run --rm -it -e SLURM_* -e PALS_* -e PMI_* -e LD_LIBRARY_PATH=/opt/udiImage/modules/mpich:/opt/udiImage/modules/mpich/dep --ipc=host \
--network=host --pid=host --privileged -v  /etc/podman_hpc/01-mpich.conf:/etc/ld.so.conf.d/02-mpich.conf \
-v /dev/xpmem:/dev/xpmem -v /dev/shm:/dev/shm -v /dev/cxi0:/dev/cxi0 -v /usr/lib/shifter/mpich-2.2:/opt/udiImage/modules/mpich \
-v /var/spool/slurmd:/var/spool/slurmd -v /run/munge:/run/munge -v /run/nscd:/run/nscd -v /etc/libibverbs.d:/etc/libibverbs.d \
-v $SCRATCH:/scratch \
ghcr.io/dingp/fedora:26-mpich \
/app/check-mpi

