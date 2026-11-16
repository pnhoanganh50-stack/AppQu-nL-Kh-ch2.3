#!/bin/bash
# Build APK trên macOS / Linux. Chạy:  bash build_apk.sh
# Cần Flutter 3.24.x và Android Studio (xem README).
set -e
cd "$(dirname "$0")"

echo "== 1/2 Tải thư viện =="
flutter pub get

echo "== 2/2 Build APK (lần đầu mất 5-15 phút) =="
flutter build apk --release

cp build/app/outputs/flutter-apk/app-release.apk QuanLyKhach.apk
echo ""
echo "XONG! File APK: $(pwd)/QuanLyKhach.apk"
