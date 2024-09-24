* This is a simple LOADM/CLOADM loader that will autostart its payload.
*
* It works by hooking the CLOSE call that occurs immediately after the
* postamble is read. It then continues reading bytes from the file until
* it receives an EOF indicator and stores them starting at physical memory
* address 0. Once EOF is found, it closes the file and transfers control
* to physical memory address 0 (at logical address 0), entering with
* interrupts disabled.

* $7000 was chosen because it will not conflict with any of DECB's buffers
* under any normal circumstances and it also does not conflict with the
* logical block used for accessing low memory. Other potentially safe
* locations include $FA0C (above super basic), $8000 (Extended Basic
* initialization code), $8D14 (nonfunction DLOAD code on Coco3), etc.
	org $7000
LOADER	ldd #$176	* restore the close routine
	std $a42E	*
	*jsr $a928	clear the lo res screen
	*ldy #$400	point to LORES screen
	*ldb #'A		* greet
	*stb ,y+		*
	clrb		set first block to load to
	ldx #$5000	init pointer to start of block
l1	stb $ffa2	set MMU for $4000-$5fff
l2	jsr $a176	get a byte from "console in"
	tst <$70	EOF?
	bne l3		brif so
	sta ,x+		save byte in memory
	cmpx #$6000	end of block?
	blo l2		brif not
	incb		next block number
	*lda #'B'
	*sta ,y+
	ldx #$4000
	bra l1		reset MMU and continue
l3	jsr $a42d	close file to be polite
	*lda #'C'
	*sta ,y+
	clr <$71	* force basic to do a cold start
	clr <$72	*
	clr <$73	*
	orcc #$50	kill interrupts
	clr $ffa0	get block 0 to logical 0
	lda #$3a        restore $4000 block
	sta $ffa2
	sta $ffd9	go turbo
	jmp >$1000	transfer control to address 0 - start payload

* the following traps the "close" that happens as soon as the postable is
* read; remember, this is a coco3 running in RAM
	org $a42e
	fdb LOADER

* setting the execute address is unneeded but it doesn't do any harm either
	end LOADER

* Some details on how this works follow.
*
* This loader exploits the way LOADM and CLOADM are implemented to allow the
* payload to be loaded from the same file as the stub loader. LOADM and CLOADM
* call the standard basic CLOSE at $A42D immediately after reading the
* postamble. Furthermore, all byte reads from the file are done via the
* standard CONSOLE IN routine at $A176 (or by short circuiting directly into
* the relevant implementation as is the case with LOADM).
*
* The first segment of the file consists of the actual loader. This assumes
* that once control is transferred to it, the currently open file contains
* the payload to be loaded at the current file offset.
*
* The second segment replaces the JSR $176 at the start of the CLOSE routine
* with a JSR to the loader. This will cause the loader to be executed before
* the file is closed but after the first stage loader has been loaded. That
* means the loader will be started automatically with the file still open.
*
* THe loader itself restores the JSR $176 instruction. Then it reads all
* of the remaining bytes from the file to physical RAM starting at $00000 and
* proceeding upward. There is no inherent size limit in the code.
*
* ONce the payload is loaded, the file is closed. This is unnecessary but it's
* polite to do so. Besides, maybe this is being loaded through another scheme
* that does benefit from the fiel being closed and which is also compatible
* with [C]LOADM. Note that this step is the reason the loader does not
* just replace the vector at $176; the vector itself could point anywhere
* so blindly replacing it would be a dangerous idea.
*
* The remainder of the loader just does some book keeping to pass control to
* the just loaded payload.
*
* When the payload starts executing, B will contain the highest physical block
* that data was loaded into. That block will also be loaded at CPU address
* $4000. X will point one byte past the last byte loaded.
