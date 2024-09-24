
all:	test

test: shanghai.asm
	lwasm --decb -9 -o loadm.bin loadm.asm
	lwasm --raw -9 -o kernel.raw kernel.asm
	lwasm --decb -l -9 -o payload.bin shanghai.asm > shanghai.lst
	slz P payload.bin payload.slz > /dev/null
	cat loadm.bin kernel.raw payload.slz > shanghai2.bin
ifneq ("$(wildcard /media/share1/COCO/drive3.dsk)","")
	decb copy -r -2 -b shanghai2.bin /media/share1/COCO/drive3.dsk,SHANG2.BIN
endif
	rm -f redistribute/shanghai.dsk
	decb dskini redistribute/shanghai.dsk
	decb copy -r -2 -b shanghai2.bin redistribute/shanghai.dsk,SHANG2.BIN
	mv shanghai2.bin redistribute/SHANG2.BIN
