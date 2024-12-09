FROM docker.io/ubuntu:16.04

MAINTAINER Pengfei Ding "dingpf@fnal.gov"


ARG DEBIAN_FRONTEND noninteractive
RUN DEBIAN_FRONTEND=${DEBIAN_FRONTEND} \
    apt-get update && \
    DEBIAN_FRONTEND=${DEBIAN_FRONTEND} \
    apt-get upgrade --yes && \
        apt-get install --yes \
        wget g++ git make && \
    apt-get clean all

# **** install mpich ****
RUN mkdir /build
RUN mkdir /mpich
RUN cd /build && wget http://www.mpich.org/static/downloads/3.4.1/mpich-3.4.1.tar.gz \
  && tar xvzf mpich-3.4.1.tar.gz && cd mpich-3.4.1 \
  && ./configure --disable-fortran  --with-device=ch3 -prefix /mpich && make -j 24 && make install && make clean && rm -rf /build

ENV PATH=${PATH}:/mpich/bin
ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/mpich/lib

ADD ../app /app
RUN mpicc /app/xthi-mpi.c -o /app/check-mpi

CMD ["/bin/bash"]
