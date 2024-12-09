#!/bin/bash
mkdir -p $SCRATCH/host_lib64
cd $SCRATCH/host_lib64
cp /lib64/*2.31* .
ln -s ld-2.31.so ld-linux-x86-64.so.2 
ln -s libanl-2.31.so libanl.so.1 
ln -s libBrokenLocale-2.31.so libBrokenLocale.so.1 
ln -s libc-2.31.so libc.so.6 
ln -s libdl-2.31.so libdl.so.2 
ln -s libm-2.31.so libm.so.6 
ln -s libmvec-2.31.so libmvec.so.1 
ln -s libnsl-2.31.so libnsl.so.1 
ln -s libnss_compat-2.31.so libnss_compat.so.2 
ln -s libnss_db-2.31.so libnss_db.so.2 
ln -s libnss_dns-2.31.so libnss_dns.so.2 
ln -s libnss_files-2.31.so libnss_files.so.2 
ln -s libnss_hesiod-2.31.so libnss_hesiod.so.2 
ln -s libpthread-2.31.so libpthread.so.0 
ln -s libresolv-2.31.so libresolv.so.2 
ln -s librt-2.31.so librt.so.1 
ln -s libutil-2.31.so libutil.so.1 

# needed by ubuntu-16.04
cp /usr/lib64/libpcre.so.1.2.13 .
ln -s libpcre.so.1.2.13 libpcre.so.1
ln -s libpcre.so.1.2.13 libpcre.so
