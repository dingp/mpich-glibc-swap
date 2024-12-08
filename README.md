# Bringing Newer glibc into Older Images for MPICH Host Swap

## The Issue to Solve

For containerized MPI applications, the host MPI library and its dependencies are swapped into the container at runtime to enable cross-node communication. However, one critical dependency not brought in is `glibc`. Due to `glibc`'s backward compatibility, the swapped-in MPI library functions correctly in container images with newer `glibc` versions. But for images with older `glibc`, applications often fail to run with the swapped-in MPI library. The `glibc` version in the image must meet or exceed the highest version required by the MPI library or its dependencies.

The error might look like this:

```=
/app/check-mpi: /lib64/libc.so.6: version `GLIBC_2.27' not found (required by /opt/udiImage/modules/mpich/dep/libfabric.so.1)
/app/check-mpi: /lib64/libc.so.6: version `GLIBC_2.26' not found (required by /opt/udiImage/modules/mpich/dep/libfabric.so.1)
/app/check-mpi: /lib64/libm.so.6: version `GLIBC_2.26' not found (required by /opt/udiImage/modules/mpich/dep/libgfortran.so.5)
/app/check-mpi: /lib64/libc.so.6: version `GLIBC_2.27' not found (required by /opt/udiImage/modules/mpich/dep/libcxi.so.1)
/app/check-mpi: /lib64/libc.so.6: version `GLIBC_2.27' not found (required by /opt/udiImage/modules/mpich/dep/libssh.so.4)
/app/check-mpi: /lib64/libc.so.6: version `GLIBC_2.27' not found (required by /opt/udiImage/modules/mpich/dep/libgssapi_krb5.so.2)
/app/check-mpi: /lib64/libselinux.so.1: no version information available (required by /opt/udiImage/modules/mpich/dep/libkrb5support.so.0)
```

In this example, the application requires `glibc` version `2.27` or above, but the image contains `glibc` version `2.25`.

```bash=
[root@nid200005 app]# /lib64/libc-2.25.so
GNU C Library (GNU libc) stable release version 2.25, by Roland McGrath et al.
Copyright (C) 2017 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.
There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.
Compiled by GNU CC version 7.2.1 20170915 (Red Hat 7.2.1-2).
Available extensions:
        crypt add-on version 2.1 by Michael Glad and others
        GNU Libidn by Simon Josefsson
        Native POSIX Threads Library by Ulrich Drepper et al
        BIND-8.2.3-T5B
libc ABIs: UNIQUE IFUNC
For bug reporting instructions, please see:
<http://www.gnu.org/software/libc/bugs.html>.
```

You can verify this using:

```bash
objdump -T <shared_lib> | grep GLIBC | sed 's/.*GLIBC_\([.0-9]*\).*/\1/g' | sort -V | tail -n 1
```

This command will reveal the highest `glibc` version required by the application’s dependencies. In this case, the maximum requirement is `GLIBC_2.27` for `libfabric.so`.

The following commands lists the `glibc` version requirements for each swapped-in library:

```bash=
for i in $(ls /usr/lib/shifter/mpich-2.2/*.so*); do
  echo $i;
  objdump -T $i | grep GLIBC | sed 's/.*GLIBC_\([.0-9]*\).*/\1/g' | sort -V | tail -n 1;
done
for i in $(ls /usr/lib/shifter/mpich-2.2/dep/*.so*); do
  echo $i;
  objdump -T $i | grep GLIBC | sed 's/.*GLIBC_\([.0-9]*\).*/\1/g' | sort -V | tail -n 1;
done
```

## Constraints on Possible Solutions

- **Runtime Modifications:** Modifying the image at runtime using tools like `patchelf` is impractical, especially for large-scale jobs (`srun -n <many_num_jobs>`).
- **Image Rebuild:** Rebuilding the image with pre-applied fixes is possible but not ideal. A better solution avoids rebuilding.

## First Attempt: Bring a Newer `libc.so`

Adding only `libc.so.6` from the host fails because `glibc` involves multiple interdependent libraries. For example:

```bash=
[root@nid200005 scratch]# LD_LIBRARY_PATH=/scratch/libc_only:$LD_LIBRARY_PATH /app/check-mpi
/app/check-mpi: /lib64/libm.so.6: version `GLIBC_2.26' not found (required by /opt/udiImage/modules/mpich/dep/libgfortran.so.5)
```

Here, `libgfortran.so.5` depends on `libm.so` with version `GLIBC_2.26`.

## Second Attempt: Bring All Related `glibc` Libraries

Even with all related libraries, the following error occurs:

```bash=
[root@nid200005 scratch]# LD_LIBRARY_PATH=/scratch/libc_libm:$LD_LIBRARY_PATH /app/check-mpi
/app/check-mpi: /lib64/libselinux.so.1: no version information available (required by /opt/udiImage/modules/mpich/dep/libkrb5support.so.0)
/app/check-mpi: relocation error: /scratch/libc_libm/libc.so.6: symbol _dl_exception_create, version GLIBC_PRIVATE not defined in file ld-linux-x86-64.so.2 with link time reference
```

This happens because `ld-linux.so.2` and `libc.so.6` are mismatched. The executable uses the hardcoded `ld-linux.so.2` path from its link time, ignoring alternatives in `LD_LIBRARY_PATH`.

## Third Attempt: Overwriting the System `ld-linux.so.2`

## Third Attempt - Can We Overwrite the System `ld-linux.so.2`?

Nice try! You cannot.

```bash
[root@nid200005 scratch]# cp /scratch/host_lib64/ld-2.31.so /lib64/
[root@nid200005 scratch]# cp /scratch/host_lib64/ld-linux-x86-64.so.2 /lib64/
cp: overwrite '/lib64/ld-linux-x86-64.so.2'? y
cp: cannot create regular file '/lib64/ld-linux-x86-64.so.2': Text file busy
```

The reason is simple: almost every binary depends on it! Even `cp` itself relies on it.

```bash
[root@nid200005 /]# ldd /bin/cp
        linux-vdso.so.1 (0x00007ffd965b1000)
        libselinux.so.1 => /lib64/libselinux.so.1 (0x00007f0981336000)
        libacl.so.1 => /lib64/libacl.so.1 (0x00007f098112d000)
        libattr.so.1 => /lib64/libattr.so.1 (0x00007f0980f28000)
        libc.so.6 => /lib64/libc.so.6 (0x00007f0980b53000)
        libpcre.so.1 => /lib64/libpcre.so.1 (0x00007f09808e1000)
        libdl.so.2 => /lib64/libdl.so.2 (0x00007f09806dd000)
        /lib64/ld-linux-x86-64.so.2 (0x00007f0981780000)
        libpthread.so.0 => /lib64/libpthread.so.0 (0x00007f09804be000)
```

If we cannot change the system `ld-linux-x86-64.so.2`, how can we use an alternate version?

---

## Fourth Attempt - Using an Alternate `ld-linux.so.2`

The path to the interpreter (`ld-linux.so.2`) is hardcoded into the binary at link time. The obvious solution is to use `patchelf` to rewrite it. However, we want to avoid modifying the binaries directly.

For reference, here’s how to use `patchelf` for this purpose. Note that this example includes the full suite of GLIBC libraries:

```bash=
# Using release-0.13 branch of https://github.com/NixOS/patchelf.git
# ./bootstrap.sh && ./configure && make -j20 && make install
[root@nid200005 app]# patchelf --set-interpreter /scratch/host_lib64/ld-2.31.so check-mpi
[root@nid200005 app]# LD_LIBRARY_PATH=/scratch/host_lib64 ./check-mpi
Hello from rank 0, on nid200005. (core affinity = 0-255)
```

This brings us to the final solution. What happens if you simply execute `/lib64/ld-linux-x86-64.so.2` on the command line?

```bash=
[root@nid200005 host_lib64]# /lib64/ld-linux-x86-64.so.2
Usage: ld.so [OPTION]... EXECUTABLE-FILE [ARGS-FOR-PROGRAM...]
You have invoked `ld.so', the helper program for shared library executables.
This program usually lives in the file `/lib/ld.so', and special directives
in executable files using ELF shared libraries tell the system's program
loader to load the helper program from this file.  This helper program loads
the shared libraries needed by the program executable, prepares the program
to run, and runs it.  You may invoke this helper program directly from the
command line to load and run an ELF executable file; this is like executing
that file itself, but always uses this helper program from the file you
specified, instead of the helper program file specified in the executable
file you run.  This is mostly of use for maintainers to test new versions
of this helper program; chances are you did not intend to run this program.

  --list                list all dependencies and how they are resolved
  --verify              verify that given object really is a dynamically linked
                        object we can handle
  --inhibit-cache       Do not use /etc/ld.so.cache
  --library-path PATH   use given PATH instead of content of the environment
                        variable LD_LIBRARY_PATH
  --inhibit-rpath LIST  ignore RUNPATH and RPATH information in object names
                        in LIST
  --audit LIST          use objects named in LIST as auditors
```

READ THE OUTPUT CAREFULLY! The solution is right there. It is as simple as running the executable with the alternate `ld.so` like the following:

```bash
[root@nid200005 /]# /scratch/host_lib64/ld-linux-x86-64.so.2 \
> --library-path /scratch/host_lib64:/opt/udiImage/modules/mpich:/opt/udiImage/modules/mpich/dep \
> /app/check-mpi
Hello from rank 0, on nid200005. (core affinity = 0-255)
```

---

### Verifying the Solution with Multi-Node MPI

```bash=
dingpf@muller:login02:/mscratch/sd/d/dingpf/mpich-glibc-swap> salloc --nodes 2 --qos interactive --time 04:00:00 --constraint cpu
salloc: Pending job allocation 893410
salloc: job 893410 queued and waiting for resources
salloc: job 893410 has been allocated resources
salloc: Granted job allocation 893410
salloc: Waiting for resource configuration
salloc: Nodes nid[200003-200004] are ready for job
dingpf@nid200003:/mscratch/sd/d/dingpf/mpich-glibc-swap> cat script/srun-glibc-swap.sh
srun --ntasks-per-node 4 -N 2  podman-hpc run --rm  --mpi \
-v $SCRATCH:/scratch \
ghcr.io/dingp/fedora:26-mpich \
/scratch/host_lib64/ld-linux-x86-64.so.2 \
--library-path /scratch/host_lib64:/opt/udiImage/modules/mpich:/opt/udiImage/modules/mpich/dep \
/app/check-mpi

dingpf@nid200003:/mscratch/sd/d/dingpf/mpich-glibc-swap> . script/srun-glibc-swap.sh
Hello from rank 3, on nid200003. (core affinity = 0-255)
Hello from rank 2, on nid200003. (core affinity = 0-255)
Hello from rank 1, on nid200003. (core affinity = 0-255)
Hello from rank 5, on nid200004. (core affinity = 0-255)
Hello from rank 6, on nid200004. (core affinity = 0-255)
Hello from rank 7, on nid200004. (core affinity = 0-255)
Hello from rank 4, on nid200004. (core affinity = 0-255)
Hello from rank 0, on nid200003. (core affinity = 0-255)
```

It works!

## Wrap-up

Exploring this topic was a fun experience like going down a rabbit hole. The full example is available in [this repository](https://github.com/dingp/mpich-glibc-swap), which includes:

- [`container/fedora-26.Dockerfile`](https://github.com/dingp/mpich-glibc-swap/blob/main/container/fedora-26.Dockerfile): A Dockerfile for the container image.
- [`app/xthi-mpi.c`](https://github.com/dingp/mpich-glibc-swap/blob/main/app/xthi-mpi.c): Source code for a simple MPI application used for testing (sourced from [NERSC documentation](https://docs.nersc.gov/jobs/affinity/xthi-mpi.c)).
- [`script/create_host_lib64.sh`](https://github.com/dingp/mpich-glibc-swap/blob/main/script/create_host_lib64.sh): A script to gather GLIBC library bundles from the host (valid for `muller` or `perlmutter` as of 2024-12-07). Note: This script could be improved to eliminate hard-coded library versions.
- Three scripts designed for compute nodes:
    - [`script/run-fedora-mpi-it.sh`](https://github.com/dingp/mpich-glibc-swap/blob/main/script/run-fedora-mpi-it.sh): Runs the container interactively with all required libraries volume-mounted, enabling live testing.
    - [`script/srun-glibc-swap.sh`](https://github.com/dingp/mpich-glibc-swap/blob/main/script/srun-glibc-swap.sh): Executes the MPI application using the appropriate `ld.so` loader.
    - [`script/srun-no-glibc-swap.sh`](https://github.com/dingp/mpich-glibc-swap/blob/main/script/srun-no-glibc-swap.sh): Demonstrates failure due to mismatched `GLIBC` versions required by the MPI libraries or their dependencies.

### Fun Fact

While searching for a base image with an older `GLIBC` version, I initially considered `RHEL7` equivalents like `ScientificLinux 7` and `CentOS 7`. Unfortunately, these proved unusable due to the lack of active repository mirrors. Without access to mirrors, a minimal DockerHub image becomes useless, as `gcc` and other utilities are required. Fortunately, `Fedora 26` still provides active mirrors and includes an appropriately aged `GLIBC` version.
