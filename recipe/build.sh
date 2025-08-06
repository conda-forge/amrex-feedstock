#!/usr/bin/env bash

# avoid side-injection of -std=c++14 flag in some toolchains
if [[ ${CXXFLAGS} == *"-std=c++14"* ]]; then
    echo "14 -> 17"
    export CXXFLAGS="${CXXFLAGS} -std=c++17"
fi
# Darwin modern C++
#   https://conda-forge.org/docs/maintainer/knowledge_base.html#newer-c-features-with-old-sdk
if [[ ${target_platform} =~ osx.* ]]; then
    export CXXFLAGS="${CXXFLAGS} -D_LIBCPP_DISABLE_AVAILABILITY"
fi
# MPI variants
if [[ ${mpi} == "nompi" ]]; then
    export USE_MPI=OFF
else
    export USE_MPI=ON
fi
# Precision variants
if [[ ${amrex_precision} == "dp" ]]; then
    export PRECISION="DOUBLE"
else
    export PRECISION="SINGLE"
fi
#   see https://github.com/conda-forge/hdf5-feedstock/blob/master/recipe/mpiexec.sh
if [[ "$mpi" == "mpich" ]]; then
    export HYDRA_LAUNCHER=fork
    #export HYDRA_LAUNCHER=ssh
fi
if [[ "$mpi" == "openmpi" ]]; then
    export OMPI_MCA_btl=self,tcp
    export OMPI_MCA_plm=isolated
    #export OMPI_MCA_plm=ssh
    export OMPI_MCA_rmaps_base_oversubscribe=yes
    export OMPI_MCA_btl_vader_single_copy_mechanism=none
fi
# CMake cannot find OpenMPI when cross-compiling for arm64 on macOS
if [[ "$mpi" == "openmpi" &&
      ${target_platform} =~ osx.* &&
      "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then

    export OPAL_PREFIX=${PREFIX}
fi

# configure
cmake \
    -S ${SRC_DIR} -B build            \
    ${CMAKE_ARGS}                     \
    -DAMReX_ASCENT=OFF                \
    -DAMReX_BUILD_TUTORIALS=OFF       \
    -DAMReX_CONDUIT=OFF               \
    -DAMReX_CUDA_LTO=OFF              \
    -DAMReX_EB=ON                     \
    -DAMReX_ENABLE_TESTS=ON           \
    -DAMReX_FFT=ON                    \
    -DAMReX_FORTRAN=OFF               \
    -DAMReX_FORTRAN_INTERFACES=OFF    \
    -DAMReX_GPU_BACKEND=NONE          \
    -DAMReX_GPU_RDC=OFF               \
    -DAMReX_HDF5=OFF                  \
    -DAMReX_HYPRE=OFF                 \
    -DAMReX_IPO=OFF                   \
    -DAMReX_MPI=${USE_MPI}            \
    -DAMReX_MPI_THREAD_MULTIPLE=OFF   \
    -DAMReX_OMP=ON                    \
    -DAMReX_PARTICLES=ON              \
    -DAMReX_PARTICLES_PRECISION=${PRECISION} \
    -DAMReX_PLOTFILE_TOOLS=OFF        \
    -DAMReX_PRECISION=${PRECISION}    \
    -DAMReX_PROBINIT=OFF              \
    -DAMReX_PIC=ON                    \
    -DAMReX_SIMD=ON                   \
    -DAMReX_SPACEDIM="1;2;3"          \
    -DAMReX_SENSEI=OFF                \
    -DAMReX_TEST_TYPE=Small           \
    -DAMReX_TINY_PROFILE=ON           \
    -DBUILD_SHARED_LIBS=ON            \
    -DCMAKE_BUILD_TYPE=Release        \
    -DCMAKE_VERBOSE_MAKEFILE=ON       \
    -DCMAKE_INSTALL_LIBDIR=lib        \
    -DCMAKE_INSTALL_PREFIX=${PREFIX}

# build
cmake --build build --parallel ${CPU_COUNT}

# test
if [[ "${CONDA_BUILD_CROSS_COMPILATION:-}" == "1" ]]; then
    echo "Skipping runtime tests due to cross-compiled target..."
else
    OMP_NUM_THREADS=2 ctest --test-dir build --output-on-failure
fi

# install
cmake --build build --target install

