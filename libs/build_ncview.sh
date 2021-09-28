#!/bin/bash

set -eux

name="ncview"
version=${1:-${STACK_ncview_version}}

software=$name-$version

cd ${HPC_STACK_ROOT}/${PKGDIR:-"pkg"}

URL="ftp://cirrus.ucsd.edu/pub/${name}/${software}.tar.gz"
[[ -d $software ]] || ( $WGET $URL; tar -xf $software.tar.gz && rm -f $software.tar.gz )
[[ ${DOWNLOAD_ONLY} =~ [yYtT] ]] && exit 0

# Hyphenated version used for install prefix
compiler=$(echo $HPC_COMPILER | sed 's/\//-/g')
mpi=$(echo $HPC_MPI | sed 's/\//-/g')

if $MODULES; then
    set +x
    source $MODULESHOME/init/bash
    module load hpc-$HPC_COMPILER
    [[ -z $mpi ]] || module load hpc-$HPC_MPI
    module try-load szip
    module try-load png
    module load hdf5
    module load netcdf
    module load udunits
    module list
    set -x
    enable_pnetcdf=$(nc-config --has-pnetcdf)
    set +x
      [[ $enable_pnetcdf =~ [yYtT] ]] && module load pnetcdf
    set -x

    prefix="${PREFIX:-"/opt/modules"}/$compiler/$mpi/$name/$version"
    if [[ -d $prefix ]]; then
        [[ $OVERWRITE =~ [yYtT] ]] && ( echo "WARNING: $prefix EXISTS: OVERWRITING!";$SUDO rm -rf $prefix ) \
                                   || ( echo "WARNING: $prefix EXISTS, SKIPPING"; exit 1 )
    fi
else
    prefix=${NCVIEW_ROOT:-"/usr/local"}
    enable_pnetcdf=$(nc-config --has-pnetcdf)
fi

if [[ ! -z $mpi ]]; then
    export CC=$MPI_CC
else
    export CC=$SERIAL_CC
fi

export CFLAGS="${STACK_CFLAGS:-} ${STACK_ncview_CFLAGS:-} -fPIC"

#HDF5_LDFLAGS="-L$HDF5_ROOT/lib"
#HDF5_LIBS="-lhdf5_hl -lhdf5"
#
#AM_LDFLAGS=$(cat $HDF5_ROOT/lib/libhdf5.settings | grep AM_LDFLAGS | cut -d: -f2)
#EXTRA_LIBS=$(cat $HDF5_ROOT/lib/libhdf5.settings | grep "Extra libraries" | cut -d: -f2)
#
#if [[ ! -z $mpi ]]; then
#  if [[ $enable_pnetcdf =~ [yYtT] ]]; then
#    PNETCDF_LDFLAGS="-L$PNETCDF_ROOT/lib"
#    PNETCDF_LIBS="-lpnetcdf"
#  fi
#fi
#
#NETCDF_LDFLAGS="-L$NETCDF_ROOT/lib"
#NETCDF_LIBS="-lnetcdf"
#
#export LDFLAGS="${PNETCDF_LDFLAGS:-} ${NETCDF_LDFLAGS:-} ${HDF5_LDFLAGS} ${AM_LDFLAGS:-}"
#export LIBS="${PNETCDF_LIBS:-} ${NETCDF_LIBS} ${HDF5_LIBS} ${EXTRA_LIBS:-}"
#export CPPFLAGS="-I${NETCDF_ROOT}/include"

[[ -d $software ]] && cd $software || ( echo "$software does not exist, ABORT!"; exit 1 )
[[ -d build ]] && rm -rf build
mkdir -p build && cd build

../configure --prefix=$prefix \
             --with-udunits2_incdir=${UDUNITS_ROOT}/include \
             --with-udunits2_libdir=${UDUNITS_ROOT}/lib

make -j${NTHREADS:-4}
[[ $MAKE_CHECK =~ [yYtT] ]] && make check
$SUDO make install

# generate modulefile from template
[[ -z $mpi ]] && modpath=compiler || modpath=mpi
$MODULES && update_modules $modpath $name $version
echo $name $version $URL >> ${HPC_STACK_ROOT}/hpc-stack-contents.log
