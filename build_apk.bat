@echo off
chcp 65001 >nul
REM Build APK tren Windows. Bam dup chuot vao file nay. Can Flutter 3.24.x.
cd /d "%~dp0"

echo == 1/2 Tai thu vien ==
call flutter pub get || goto :err

echo == 2/2 Build APK (lan dau mat 5-15 phut) ==
call flutter build apk --release || goto :err

copy /Y build\app\outputs\flutter-apk\app-release.apk QuanLyKhach.apk >nul
echo.
echo XONG! File APK: %cd%\QuanLyKhach.apk
pause
exit /b 0

:err
echo.
echo CO LOI! Doc thong bao o tren hoac xem muc "Loi thuong gap" trong README.
pause
exit /b 1
