#!/bin/bash -x                                     
# machine_name="gaea" 
# platform="intel18"
#machine_name="tiger" 
#platform="intel18"
#machine_name="googcp" 
#platform="intel19"
#machine_name = "ubuntu"
#platform     = "pgi18"                                             
#machine_name="ubuntu" 
#platform="gnu7"
# machine_name = "gfdl-ws" 
#platform     = "intel15"
machine_name = "gfdl-ws"
platform     = "gnu11" 
#machine_name = "theta"   
#platform     = "intel16"
#machine_name="lscsky50"
#platform="intel19up2_avx1" #"intel18_avx1" # "intel18up2_avx1" 
target="prod" #"debug-openmp"       
flavor="mom6solo" #"mom6solo

usage()
{
    echo "usage: linux-build.bash -m googcp -p intel19 -t prod -f mom6sis2"
}

# parse command-line arguments
while getopts "m:p:t:f:h" Option
do
   case "$Option" in
      m) machine_name=${OPTARG};;
      p) platform=${OPTARG} ;;
      t) target=${OPTARG} ;;
      f) flavor=${OPTARG} ;;
      h) usage ; exit ;;
   esac
done

rootdir=`dirname $0`
abs_rootdir=`cd $rootdir && pwd`


#load modules              
source $MODULESHOME/init/bash
source $abs_rootdir/$machine_name/$platform.env
. $abs_rootdir/$machine_name/$platform.env

makeflags="NETCDF=4 -j 4"

if [[ "$target" =~ "openmp" ]] ; then 
   makeflags="$makeflags OPENMP=1" 
fi

if [[ "$target" =~ "openacc" ]] ; then 
   makeflags="$makeflags OPENACC=1" 
fi

if [[ $target =~ "repro" ]] ; then
   makeflags="$makeflags REPRO=1"
fi

if [[ $target =~ "prod" ]] ; then
   makeflags="$makeflags PROD=1"
fi

if [[ $target =~ "avx512" ]] ; then
   makeflags="$makeflags PROD=1 AVX=512"
fi

if [[ $target =~ "debug" ]] ; then
   makeflags="$makeflags DEBUG=1"
fi

srcdir=$abs_rootdir/../src

mkdir -p build/$machine_name-$platform/shared/$target
pushd build/$machine_name-$platform/shared/$target   
rm -f path_names                       
# $srcdir/mkmf/bin/list_paths $srcdir/FMS/{affinity,amip_interp,column_diagnostics,diag_integral,drifters,horiz_interp,memutils,parser,sat_vapor_pres,string_utils,topography,astronomy,constants,diag_manager,field_manager,include,monin_obukhov,platform,tracer_manager,axis_utils,coupler,fms,fms2_io,interpolator,mosaic,mosaic2,random_numbers,time_interp,tridiagonal,block_control,data_override,exchange,mpp,time_manager}/ $srcdir/FMS/libFMS.F90
$srcdir/mkmf/bin/list_paths $srcdir/FMS/*/ $srcdir/FMS/libFMS.F90

$srcdir/mkmf/bin/mkmf -t $abs_rootdir/$machine_name/$platform.mk -p libfms.a -c "-Duse_libMPI -Duse_netCDF -DMAXFIELDMETHODS_=800" path_names

make $makeflags libfms.a         

if [ $? -ne 0 ]; then
   echo "Could not build the FMS library!"
   exit 1
fi

popd

if [[ $flavor =~ "mom6generic" ]] ; then
    mkdir -p build/$machine_name-$platform/ocean_generic/$target
    pushd build/$machine_name-$platform/ocean_generic/$target
    rm -f path_names
    # "mom6/src/MOM6/config_src/memory/dynamic_symmetric mom6/src/MOM6/config_src/drivers/FMS_cap mom6/src/MOM6/src/*/ mom6/src/MOM6/src/*/*/ mom6/src/MOM6/config_src/external/ODA_hooks mom6/src/MOM6/config_src/external/stochastic_physics mom6/src/MOM6/config_src/external/drifters mom6/src/MOM6/config_src/external/database_comms ocean_BGC/generic_tracers ocean_BGC/mocsy/src mom6/src/MOM6/pkg/GSW-Fortran/*/ mom6/src/MOM6/config_src/infra/FMS1">

   #  $srcdir/mkmf/bin/list_paths $srcdir/MOM6/{config_src/infra/FMS1,config_src/memory/dynamic_symmetric,config_src/drivers/FMS_cap,config_src/external/ODA_hooks,config_src/external/stochastic_physics,config_src/external/drifters,config_src/external/database_comms,pkg/GSW-Fortran/{modules,toolbox}/,src/{*,*/*}/} $srcdir/SIS2/{config_src/dynamic,config_src/external/Icepack_interfaces,src} $srcdir/icebergs/ $srcdir/FMS/{coupler,include}/ $srcdir/{ocean_BGC/generic_tracers,ocean_BGC/mocsy/src}/ $srcdir/{atmos_null,ice_param,land_null,coupler/shared/,coupler/full/}/
    $srcdir/mkmf/bin/list_paths  $srcdir/MOM6/config_src/memory/dynamic_symmetric $srcdir/MOM6/config_src/drivers/FMS_cap $srcdir/MOM6/src/*/ $srcdir/MOM6/src/*/*/ $srcdir/MOM6/config_src/external/ODA_hooks $srcdir/MOM6/config_src/external/stochastic_physics $srcdir/MOM6/config_src/external/drifters $srcdir/MOM6/config_src/external/database_comms $srcdir/{ocean_BGC/generic_tracers,ocean_BGC/mocsy/src}/  $srcdir/MOM6/pkg/GSW-Fortran/{modules,toolbox}/ $srcdir/MOM6/config_src/infra/FMS2 $srcdir/icebergs/ $srcdir/SIS2/{config_src/dynamic,config_src/external/Icepack_interfaces,src}  $srcdir/FMS/{coupler,include}/ $srcdir/{atmos_null,ice_param,land_null,coupler/shared/,coupler/full/}/

    $srcdir/mkmf/bin/mkmf -t $abs_rootdir/$machine_name/$platform.mk -o "-I../../shared/$target" -p MOM6 -l "-L../../shared/$target -lfms" -c '-DMAX_FIELDS_=100 -DNOT_SET_AFFINITY -D_USE_MOM6_DIAG -D_USE_GENERIC_TRACER  -DUSE_PRECISION=2 -D_USE_LEGACY_LAND_ -Duse_AM3_physics' path_names


   if [[ "$target" =~ "managedACC" ]] ; then 
      sed -e 's/-c\(.*\)COBALT/-acc -ta=nvidia:managed -Minfo=accel -c \1COBALT/' -i Makefile
      sed -e 's/-lfms/-lfms -acc/' -i Makefile
   fi

    make $makeflags MOM6

elif [[ $flavor =~ "mom6sis2" ]] ; then
    mkdir -p build/$machine_name-$platform/ocean_ice/$target
    pushd build/$machine_name-$platform/ocean_ice/$target
    rm -f path_names
    # "mom6/src/MOM6/config_src/memory/dynamic_symmetric mom6/src/MOM6/config_src/drivers/FMS_cap mom6/src/MOM6/src/*/ mom6/src/MOM6/src/*/*/ mom6/src/MOM6/config_src/external/ODA_hooks mom6/src/MOM6/config_src/external/stochastic_physics mom6/src/MOM6/config_src/external/drifters mom6/src/MOM6/config_src/external/database_comms ocean_BGC/generic_tracers ocean_BGC/mocsy/src mom6/src/MOM6/pkg/GSW-Fortran/*/ mom6/src/MOM6/config_src/infra/FMS1">

   #  $srcdir/mkmf/bin/list_paths $srcdir/MOM6/{config_src/infra/FMS1,config_src/memory/dynamic_symmetric,config_src/drivers/FMS_cap,config_src/external/ODA_hooks,config_src/external/stochastic_physics,config_src/external/drifters,config_src/external/database_comms,pkg/GSW-Fortran/{modules,toolbox}/,src/{*,*/*}/} $srcdir/SIS2/{config_src/dynamic,config_src/external/Icepack_interfaces,src} $srcdir/icebergs/ $srcdir/FMS/{coupler,include}/ $srcdir/{ocean_BGC/generic_tracers,ocean_BGC/mocsy/src}/ $srcdir/{atmos_null,ice_param,land_null,coupler/shared/,coupler/full/}/
    $srcdir/mkmf/bin/list_paths  $srcdir/MOM6/config_src/memory/dynamic_symmetric $srcdir/MOM6/config_src/drivers/FMS_cap $srcdir/MOM6/src/*/ $srcdir/MOM6/src/*/*/ $srcdir/MOM6/config_src/external/ODA_hooks $srcdir/MOM6/config_src/external/stochastic_physics $srcdir/MOM6/config_src/external/GFDL_ocean_BGC $srcdir/MOM6/config_src/external/drifters $srcdir/MOM6/config_src/external/database_comms  $srcdir/MOM6/pkg/GSW-Fortran/{modules,toolbox}/ $srcdir/MOM6/config_src/infra/FMS2 $srcdir/icebergs/ $srcdir/SIS2/{config_src/dynamic,config_src/external/Icepack_interfaces,src}  $srcdir/FMS/{coupler,include,fms2_io}/ $srcdir/{atmos_null,ice_param,land_null,coupler/shared/,coupler/full/}/

    $srcdir/mkmf/bin/mkmf -t $abs_rootdir/$machine_name/$platform.mk -o "-I../../shared/$target" -p MOM6SIS2 -l "-L../../shared/$target -lfms" -c '-DMAX_FIELDS_=100 -DNOT_SET_AFFINITY -D_USE_MOM6_DIAG -D_USE_GENERIC_TRACER  -DUSE_PRECISION=2 -D_USE_LEGACY_LAND_ -Duse_AM3_physics' path_names


   if [[ "$target" =~ "managedACC" ]] ; then 
      sed -e 's/-c\(.*\)COBALT/-acc -ta=nvidia:managed -Minfo=accel -c \1COBALT/' -i Makefile
      sed -e 's/-lfms/-lfms -acc/' -i Makefile
   fi

    make $makeflags MOM6SIS2

elif [[ $flavor =~ "mom6coupled" ]] ; then
    mkdir -p build/$machine_name-$platform/ocean_coupled/$target
    pushd build/$machine_name-$platform/ocean_coupled/$target
    rm -f path_names  
   #  $srcdir/mkmf/bin/list_paths  $srcdir/MOM6/config_src/memory/dynamic_symmetric $srcdir/MOM6/config_src/drivers/FMS_cap $srcdir/MOM6/src/*/ $srcdir/MOM6/src/*/*/ $srcdir/MOM6/config_src/external/ODA_hooks $srcdir/MOM6/config_src/external/stochastic_physics $srcdir/MOM6/config_src/external/drifters $srcdir/MOM6/config_src/external/database_comms $srcdir/{ocean_BGC/generic_tracers,ocean_BGC/mocsy/src}/  $srcdir/MOM6/pkg/GSW-Fortran/{modules,toolbox}/ $srcdir/MOM6/config_src/infra/FMS2 $srcdir/icebergs/ $srcdir/SIS2/{config_src/dynamic,config_src/external/Icepack_interfaces,src}  $srcdir/FMS/{coupler,include}/ $srcdir/{atmos_null,ice_param,land_null,coupler/shared/,coupler/full/}/

    $srcdir/mkmf/bin/list_paths $srcdir/MOM6/{config_src/infra/FMS2,config_src/memory/dynamic_symmetric,config_src/drivers/FMS_cap,config_src/external/GFDL_ocean_BGC,config_src/external/ODA_hooks,config_src/external/stochastic_physics,config_src/external/drifters,config_src/external/database_comms,pkg/GSW-Fortran/{modules,toolbox}/,src/{*,*/*}}/ $srcdir/{atmos_null,ice_null,land_null,coupler/shared/,coupler/full/}/

    $srcdir/mkmf/bin/mkmf -t $abs_rootdir/$machine_name/$platform.mk -o "-I../../shared/$target" -p MOM6 -l "-L../../shared/$target -lfms" -c '-DMAX_FIELDS_=100 -DNOT_SET_AFFINITY -D_USE_MOM6_DIAG -DUSE_PRECISION=2 -D_USE_LEGACY_LAND_ -Duse_AM3_physics' path_names

    make $makeflags MOM6

else 
    mkdir -p build/$machine_name-$platform/ocean_only/$target
    pushd build/$machine_name-$platform/ocean_only/$target
    rm -f path_names
    $srcdir/mkmf/bin/list_paths $srcdir/MOM6/{config_src/infra/FMS2,config_src/memory/dynamic_symmetric,config_src/drivers/solo_driver,config_src/external/GFDL_ocean_BGC,config_src/external/ODA_hooks,config_src/external/stochastic_physics,config_src/external/drifters,config_src/external/database_comms,pkg/GSW-Fortran/{modules,toolbox}/,src/{*,*/*}}/ $srcdir/FMS/{coupler,include,fms2_io}/
    $srcdir/mkmf/bin/mkmf -t $abs_rootdir/$machine_name/$platform.mk -o "-I../../shared/$target" -p MOM6 -l "-L../../shared/$target -lfms" -c '-Duse_libMPI -Duse_netCDF -DSPMD' path_names

    make $makeflags MOM6
fi
