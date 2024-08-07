Windows install:
git clone https://github.com/SamManibog/nvim "$env:LOCALAPPDATA"

requirements:
packer.nvim

recommendations:
MinGW specifed in environment
use cmake flags cmake -B build -D CMAKE_EXPORT_COMPILE_COMMANDS=1 -D CMAKE_C_COMPILER=gcc -D CMAKE_CXX_COMPILER=g++ -G "MinGW Makefiles" -S .
