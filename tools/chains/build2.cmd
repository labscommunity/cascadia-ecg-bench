@echo off
call "C:\BuildTools\VC\Auxiliary\Build\vcvars64.bat" >nul
call C:\ov\setupvars.bat
set INTEL_OPENVINO_DIR=C:\ov
set PATH=C:\Users\devcloud\.cargo\bin;%PATH%
set CARGO_BUILD_TARGET=x86_64-pc-windows-msvc
cd /d C:\ecgbench\src\cascadia
git fetch C:\ecgbench\clean.bundle feat/qwen35-keepalive-profiling:refs/heads/feat/qwen35-keepalive-profiling-bundle -f
git checkout -q -f feat/qwen35-keepalive-profiling-bundle
git log --oneline -1
cargo build --release -p cascadia --features openvino --target x86_64-pc-windows-msvc
if %ERRORLEVEL%==0 (
  if not exist C:\ecgbench\rt\clean mkdir C:\ecgbench\rt\clean
  robocopy C:\ecgbench\rt\spec C:\ecgbench\rt\clean *.dll /NJH /NJS /NDL /NFL >nul
  copy /Y target\x86_64-pc-windows-msvc\release\cascadia.exe C:\ecgbench\rt\clean\cascadia.exe
  echo BUILD2_DONE > C:\ecgbench\results\build2.done
)
echo EXIT %ERRORLEVEL%
