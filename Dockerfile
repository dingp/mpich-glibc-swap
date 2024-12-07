FROM docker.io/fedora:26

MAINTAINER Pengfei Ding "dingpf@fnal.gov"

RUN yum clean all \
 && yum -y update \
 && yum -y install findutils wget gcc gcc-c++ git \
 && yum clean all

# **** install mpich ****
RUN mkdir /build
RUN mkdir /mpich
RUN cd /build && wget http://www.mpich.org/static/downloads/3.4.1/mpich-3.4.1.tar.gz \
  && tar xvzf mpich-3.4.1.tar.gz && cd mpich-3.4.1 \
  && ./configure --disable-fortran  --with-device=ch3 -prefix /mpich && make -j 24 && make install && make clean && rm -rf /build

ENV PATH=${PATH}:/mpich/bin
ENV LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/mpich/lib


ENTRYPOINT ["/bin/bash"]
