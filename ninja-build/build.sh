#!/usr/bin/env bash
# Modified @shantoze

# Fungsi build yang sedikit dimodifikasi untuk menerima CMAKE_PATH dan NINJA_PATH
build(){
    abi=$1
    current_cmake_path=$2
    current_ninja_path=$3
    current_cmake_version=$4 # Tambahkan parameter untuk menampilkan versi CMake yang sedang digunakan

    ndkRoot=${ANDROID_NDK_HOME}
    sdkRoot=${ANDROID_SDK_ROOT}
    if [[ ${ndkRoot} == "" ]]; then
        ndkRoot=${ANDROID_NDK_ROOT}
    fi
    if [[ ${ndkRoot} == "" ]]; then
        echo "ANDROID_NDK_HOME or ANDROID_NDK_ROOT not defined"
        exit 1
    fi
    
    echo "--- Membangun untuk ABI: ${abi} menggunakan CMake versi: ${current_cmake_version} ---"

    # Direktori generasi akan mencakup versi CMake dan ABI untuk menghindari konflik
    generationDir="build/release/${current_cmake_version}/${abi}" 
    echo "-- Build ninja di ${generationDir}"
    mkdir -p "${generationDir}"
    # Gunakan pushd dan popd untuk mengelola direktori kerja dengan lebih baik
    pushd "${generationDir}" || exit 1 

    "${current_cmake_path}" \
        -DCFLAGS=-fstack-protector-all \
        -DCXXFLAGS=-fstack-protector-all \
        -DCMAKE_GENERATOR=Ninja \
        -DCMAKE_MAKE_PROGRAM="${current_ninja_path}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_TOOLCHAIN_FILE=${ndkRoot}/build/cmake/android.toolchain.cmake \
        -DANDROID_ABI=${abi} \
        -DANDROID_NATIVE_API_LEVEL=22 \
        -DANDROID_NDK=${ndkRoot} \
        ../..
    
    if [ $? -ne 0 ]; then
        echo "CMake configure gagal untuk versi ${current_cmake_version} dan ABI ${abi}"
        popd
        return 1 # Mengindikasikan kegagalan
    fi

    "${current_cmake_path}" --build . --target all
    
    if [ $? -ne 0 ]; then
        echo "CMake build gagal untuk versi ${current_cmake_version} dan ABI ${abi}"
        popd
        return 1 # Mengindikasikan kegagalan
    fi

    popd # Kembali ke direktori sebelumnya
    echo "--- Selesai membangun untuk ABI: ${abi} menggunakan CMake versi: ${current_cmake_version} ---"
    echo ""
}

# Fungsi utama untuk menjalankan build untuk semua versi CMake yang ditemukan
run_all_cmake_versions(){
    sdkRoot=${ANDROID_SDK_ROOT}
    if [[ ${sdkRoot} == "" ]]; then
        echo "ANDROID_SDK_ROOT not defined"
        exit 1
    fi

    declare -a found_cmake_versions
    if [[ -d "${sdkRoot}/cmake" ]]; then
        # Cari semua direktori versi CMake
        mapfile -t found_cmake_versions < <(ls -d "${sdkRoot}/cmake/"*/ | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -V)
    fi

    if [[ ${#found_cmake_versions[@]} -eq 0 ]]; then
        echo "Tidak dapat menemukan versi CMake di ${sdkRoot}/cmake/. Harap instal CMake."
        exit 1
    fi

    target_abi=$1 # Ambil ABI dari argumen fungsi ini

    for cmake_version in "${found_cmake_versions[@]}"; do
        CMAKE_PATH="${sdkRoot}/cmake/${cmake_version}/bin/cmake"
        NINJA_PATH="${sdkRoot}/cmake/${cmake_version}/bin/ninja"

        if [[ ! -f "${CMAKE_PATH}" ]]; then
            echo "Peringatan: File CMake tidak ditemukan di ${CMAKE_PATH}, melangkahi versi ini."
            continue # Lanjut ke versi berikutnya
        fi
        if [[ ! -f "${NINJA_PATH}" ]]; then
            echo "Peringatan: File Ninja tidak ditemukan di ${NINJA_PATH}, melangkahi versi ini."
            continue # Lanjut ke versi berikutnya
        fi

        build "${target_abi}" "${CMAKE_PATH}" "${NINJA_PATH}" "${cmake_version}"
        # Jika build gagal, Anda mungkin ingin menghentikan skrip atau hanya mencatatnya
        if [ $? -ne 0 ]; then
            echo "Build gagal untuk ${target_abi} dengan CMake ${cmake_version}. Melanjutkan ke versi berikutnya (jika ada)."
            # Anda bisa exit di sini jika ingin menghentikan proses ketika ada satu kegagalan
            # exit 1
        fi
    done
}

# Jalankan build untuk armeabi-v7a dengan semua versi CMake yang ditemukan
run_all_cmake_versions armeabi-v7a

# Anda juga bisa menjalankan untuk arm64-v8a secara terpisah jika diperlukan
# run_all_cmake_versions arm64-v8a
