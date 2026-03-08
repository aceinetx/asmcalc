.PHONY: all clean

all: asmcalc
clean: 
	rm -rf *.o asmcalc

asmcalc.o: asmcalc.s
	fasm asmcalc.s

asmcalc: asmcalc.o
	ld asmcalc.o -o asmcalc -m elf_i386
