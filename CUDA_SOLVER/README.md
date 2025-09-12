# CUDA solver  - the bruteforce tool for ARweave puzzles that relies on NVIDIA GPUs.

Currently assembled targeting mainly the LINUX systems ( i have not verified / tuned it for WINDOWS )

# Instruction

1. First, you'll need to upload the "sources" folder to your (linux) machine (AND, optionally, the python script "brute_AR.py")

2. The CUDA sources requires compilation with with use of Nvidia CUDA Compiler (nvcc) and so you will need to install/configure the nvcc + nvidia drivers on your machine.

3. Having a correctly installed/configured nvcc - proceed for the solver compilation, that could be done simply in a single line shown below, that will compile the sources into an executable called "cu_brute_ar"

nvcc ./sources/main.cu ./sources/manager.cu ./sources/KernelStride.cu ./sources/GPU.cu ./sources/tools.cpp -arch=compute_75 -code=sm_75 -O3 -o cu_brute_ar

4. This executable ("cu_brute_ar" - compiled from sources described at step 3) can perform a single-gpu bruteforce job specified with command line arguments:






The core of this program been composed and shared by an active (puzzle solvers) community member that has his own git - check hiw variant of wrapper [1](https://github.com/Solutio-Cursus/arweave-puzzle-cuda-solver). I have built my own wrapper around this crypto core in order to make it more familliar for me and to my own use, but anyone is wellcome to try it out. Some may found it overload and heavy, i udnerstand this - and i am openned for advices and propositions!





### References:

[1] CUDA core coder - https://github.com/Solutio-Cursus/arweave-puzzle-cuda-solver
