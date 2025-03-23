set -e

as asm.S -o result.o
ld result.o -o result
