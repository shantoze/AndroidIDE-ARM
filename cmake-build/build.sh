#!/usr/bin/env bash

# Modified @shantoze

# Fungsi 'build' yang dimodifikasi untuk menerima path CMake dan Ninja
# serta versi CMake yang sedang digunakan.
build(){
    abi=$1 # ABI target (misal: arm64-v8a, armeabi-v7a)
    current_cmake_path=$2 # Path lengkap ke executable CMake untuk versi ini
    current_ninja_path=$3 # Path lengkap ke executable Ninja untuk versi ini
    current_cmake_version=$4 # Versi CMake yang sedang digunakan (misal: 3.22.1)

    ndkRoot=${ANDROID_NDK_HOME}
    sdkRoot=${ANDROID_SDK_ROOT}

    # Periksa apakah ANDROID_NDK_HOME atau ANDROID_NDK_ROOT sudah didefinisikan
    if [[ -z "${ndkRoot}" ]]; then # Menggunakan -z untuk memeriksa string kosong
        ndkRoot=${ANDROID_NDK_ROOT}
    fi
    if [[ -z "${ndkRoot}" ]]; then
        echo "Kesalahan: ANDROID_NDK_HOME atau ANDROID_NDK_ROOT tidak didefinisikan."
        return 1 # Mengindikasikan kegagalan fungsi
    fi
    
    echo "--- Memulai build untuk ABI: ${abi} menggunakan CMake versi: ${current_cmake_version} ---"

    # Direktori output build akan unik untuk setiap kombinasi versi CMake dan ABI
    generationDir="build/release/${current_cmake_version}/${abi}" 
    echo "-- Membuat direktori build: ${generationDir}"
    mkdir -p "${generationDir}"

    # Menggunakan pushd untuk berpindah ke direktori build dan popd untuk kembali
    # '|| exit 1' akan menghentikan skrip jika pushd gagal (misal: direktori tidak bisa dibuat)
    pushd "${generationDir}" || { echo "Kesalahan: Gagal berpindah ke direktori ${generationDir}"; return 1; }

    echo "-- Menjalankan konfigurasi CMake..."
    # Menjalankan CMake dengan parameter yang diberikan
    # Menggunakan tanda kutip ganda untuk variabel path agar aman dari spasi
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
        ../.. # Kembali dua level ke root proyek
    
    # Memeriksa kode keluar dari perintah CMake sebelumnya
    if [ $? -ne 0 ]; then
        echo "Kesalahan: Konfigurasi CMake gagal untuk versi ${current_cmake_version} dan ABI ${abi}."
        popd # Pastikan kembali ke direktori sebelumnya
        return 1 # Mengindikasikan kegagalan
    fi

    echo "-- Menjalankan proses build CMake..."
    # Menjalankan proses build
    "${current_cmake_path}" --build . --target all
    
    # Memeriksa kode keluar dari perintah build sebelumnya
    if [ $? -ne 0 ]; then
        echo "Kesalahan: Proses build CMake gagal untuk versi ${current_cmake_version} dan ABI ${abi}."
        popd # Pastikan kembali ke direktori sebelumnya
        return 1 # Mengindikasikan kegagalan
    fi

    popd # Kembali ke direktori sebelumnya setelah selesai
    echo "--- Build selesai untuk ABI: ${abi} menggunakan CMake versi: ${current_cmake_version} ---"
    echo ""
    return 0 # Mengindikasikan keberhasilan fungsi
}

# Fungsi utama untuk menemukan semua versi CMake dan menjalankan build untuk setiap versi
run_all_cmake_versions(){
    sdkRoot=${ANDROID_SDK_ROOT}
    if [[ -z "${sdkRoot}" ]]; then
        echo "Kesalahan: ANDROID_SDK_ROOT tidak didefinisikan."
        exit 1
    fi

    declare -a found_cmake_versions # Mendeklarasikan array untuk menyimpan versi CMake
    if [[ -d "${sdkRoot}/cmake" ]]; then
        # Mencari semua direktori versi CMake, mengekstrak nomor versi, dan mengurutkannya secara versi
        # mapfile -t digunakan untuk membaca output ke dalam array
        mapfile -t found_cmake_versions < <(ls -d "${sdkRoot}/cmake/"*/ 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | sort -V)
    fi

    if [[ ${#found_cmake_versions[@]} -eq 0 ]]; then
        echo "Peringatan: Tidak dapat menemukan versi CMake di ${sdkRoot}/cmake/. Harap instal CMake."
        # Anda bisa memilih untuk keluar di sini atau melanjutkan (jika tidak ada versi CMake)
        exit 1 
    fi

    target_abi=$1 # Ambil ABI target dari argumen fungsi ini (misal: arm64-v8a)

    echo "Ditemukan versi CMake: ${found_cmake_versions[*]}"

    # Iterasi melalui setiap versi CMake yang ditemukan
    for cmake_version in "${found_cmake_versions[@]}"; do
        CMAKE_PATH="${sdkRoot}/cmake/${cmake_version}/bin/cmake"
        NINJA_PATH="${sdkRoot}/cmake/${cmake_version}/bin/ninja"

        # Memeriksa apakah file executable CMake dan Ninja benar-benar ada
        if [[ ! -f "${CMAKE_PATH}" ]]; then
            echo "Peringatan: File CMake tidak ditemukan di ${CMAKE_PATH}. Melangkahi versi ini."
            continue # Lanjut ke iterasi berikutnya (versi CMake selanjutnya)
        fi
        if [[ ! -f "${NINJA_PATH}" ]]; then
            echo "Peringatan: File Ninja tidak ditemukan di ${NINJA_PATH}. Melangkahi versi ini."
            continue # Lanjut ke iterasi berikutnya
        fi

        # Memanggil fungsi 'build' dengan path dan versi yang sesuai
        build "${target_abi}" "${CMAKE_PATH}" "${NINJA_PATH}" "${cmake_version}"
        
        # Memeriksa apakah build berhasil untuk versi CMake dan ABI ini
        if [ $? -ne 0 ]; then
            echo "Peringatan: Build gagal untuk ABI ${target_abi} dengan CMake ${cmake_version}. Melanjutkan ke versi berikutnya (jika ada)."
            # Jika Anda ingin menghentikan seluruh proses jika ada satu kegagalan,
            # Anda bisa menambahkan 'exit 1' di sini.
        fi
    done
    echo "Selesai memproses semua versi CMake yang ditemukan."
}

# --- Eksekusi Skrip ---
# Panggil fungsi utama untuk menjalankan build untuk ABI tertentu
# Misalnya, untuk arm64-v8a:
# run_all_cmake_versions arm64-v8a

# Jika Anda juga ingin membangun untuk armeabi-v7a, Anda bisa memanggilnya lagi:
run_all_cmake_versions armeabi-v7a
