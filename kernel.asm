* This is the actual kernel loader. It's sole purpose is to perform all the
* necessary relocations for the actual kernel binary which is provided as a
* DECB format blob of bytes immediately following this loader in memory.
*
* This always executes starting at address $1000. That also means we can use
* (and *should* use) absolute addressing.
*
* This ABSOLUTELY MUST be running at ABSOLUTE address $1000 in MMU block 0.
*
* The DECB payload can mess with anything, including I/O stuff and the MMU
* but IT MUST NOT modify FFA0 or FFA1. It further MUST NOT load anything
* below $4000 and it must make sure it doesn't overwrite the payload while
* loading. That means if the payload plus this header takes up 32K, then
* the lowest 4 MMU blocks of physical memory must not be overwritten.
*
* NOTE: if you need to load a payload chunk into a logical memory space
* that overlaps $0000 through $3FFF, preprocess your payload to break it
* into segments that adjust the MMU in other logical blocks and loads it
* there. So, for instance, assemble your block of code to a RAW target (as
* though building a ROM for instance), then cut it into 8K chunks, add
* a block to the payload file to set say FFA2, then a preamble to load $2000
* bytes at $4000, then the 8K chunk. Lather, rinse, repeat for each chunk
* keeping in mind that the last chunk can be smaller than 8K.
*
* As long as the final chunk is a postamble with an execution address above
* $4000, your program will execute properly.
*
* NOTE also that you can modify the code sequence at l2 to change how
* control is transferred to the execution address. For instance by putting
* the required block in FFA1 and jumping to a specific address. For instance.
	org $1000
loader	lds #tempstack+32	put the stack somewhere so we can use jsr
* set up display screen for debugging
	*lda #$4C
	*sta $ff90
	*lda #$03
	*sta $ff98
	*lda #$0d
	*sta $ff99
	*clr $ff9a
	*clr $ff9b
	*clr $ff9c
	*clr $ff9f
	*ldd #screen
	*std >screenloc
	*ldd #screen/8
	*std $ff9d
	*ldu #startmess
	*jsr >outstr
l0	jsr >getbyte		fetch block flag
	bne l2			brif postamble
	*ldu #blockmess
	*jsr >outstr
	jsr >getbyte		fetch MSB of length
	stb >tword		save it
	*jsr outhex
	jsr >getbyte		fetch LSB of length
	stb >tword+1		save it
	*jsr outhex
	ldy >tword		get length in Y for counting
	jsr >getbyte		fetch MSB of start address
	stb >tword		save it
	*jsr outhex
	jsr >getbyte		fetch LSB of start address
	stb >tword+1		save it
	*jsr outhex
	*lda #13
	*jsr outchr
	ldu >tword		get address to U
l1	jsr >getbyte		fetch block byte
	stb ,u+			save byte in memory
	leay -1,y		end of block?
	bne l1			brif not
	bra l0			look for another block
l2	jsr >getbyte		skip unused byte
	jsr >getbyte		skip unused byte
	*ldu #execmess
	*jsr outstr
	jsr >getbyte		fetch MSB of execute address
	stb >tword		save it
	*jsr outhex
	jsr >getbyte		fetch LSB of execute address
	stb >tword+1		save it
	*jsr outhex
	*lda #13
	*jsr outchr
	jmp [tword]		transfer control to the kernel
tword	fdb 0			temp storage used above
cblock	fcb 0			current block for reading bytes from
caddr	fdb payload+$2000	current address inside block
tag	fcb 0			current tag byte being processed (slz)
len	fcb 0			current length being copied
tagcnt	fcb 0			current bit number inside tag byte
lbptr	fdb 0           	current address reading in buffer
lbwptr	fdb 0           	current address writing in buffer
tempstack
	zmb 32			stack buffer for calling getbyte
; this routine fetches bytes from the payload
;
; Because the payload is SLZ compressed, it needs several variables
; to keep track of its operation. Also, because this is *stream* based
; it cannot simply refer back to the location of previously decompressed
; data for the look behind references. That means it must maintain a
; 4096 byte ring buffer so every byte returned will be written to the current
; offset in the ring buffer.
; Memory block $37 will be used for the ring buffer which allows
; for buffer offsets to be in the range of $000 through $0FFF (actually
; $2000 through $2FFF since it will be accessed in CPU block 1)
;
; set up this routine by putting the first memory block number
; into cblock and the current source address in the block (plus $2000)
; into caddr. Set lbwptr to $2000 and tagcnt to zero.

savebuf
	stb [lbwptr]		save in buffer
	ldd >lbwptr		; bump ptr
	addd #1			;
	anda #$0F		;
	std >lbwptr		;
	rts
fetchbyte
	lda >cblock		fetch block
	ldx >caddr		fetch ptr
	sta >$ffa1		set MMU
	ldb ,x+			get byte
	cmpx #$4000		end of block?
	blo fb0			brif not
	ldx #$2000		reset ptr
	inca			; bump MMU block
	sta >cblock		;
fb0	stx >caddr		save new pointer
	rts
getbyte	
	pshs a,b,x		save regs
	lda >len		get copy length
	beq gbnc		brif not copying
gbcp	lda [lbptr]		fetch byte
	sta 1,s			save in return spot
	ldd >lbptr		get address
	addd #1			* bump it and wrap to $2000 if needed
	anda #$0F		*
	std >lbptr		*
	dec >len		reduce copy length
gbret	ldb 1,s			* add byte to ring buffer
	bsr savebuf		*
	tst 1,s			set flags
	puls a,b,x,pc		return byte
gbnc	lda tagcnt		get tag count
	bne gbot		brif don't need a new tag byte
	bsr fetchbyte		get byte from source block
	stb >tag		save tag byte
	lda #8			; set counter
	sta >tagcnt		;
gbot	lsl >tag		test next flag
	dec >tagcnt		decrease tag counter (does not affect carry)
	bcs gblb		brif we have a look behind
	bsr fetchbyte		get the next byte
	stb 1,s			save return value
	bra gbret		return byte
gblb	bsr fetchbyte		fetch next byte (MSB)
	stb ,--s		save on stack
	andb #$0F		; calc length
	addb #2			;
	stb >len		save length
	ldb ,s			get back MSB
	lsrb			; shift offset bits over
	lsrb			;
	lsrb			;
	lsrb			;
	stb ,s			save offset MSB
	bsr fetchbyte		fetch next byte (LSB)
	stb 1,s			save on stack
	ldd >lbwptr		get current ring buffer ptr
	subd ,s++		subtract offset
	anda #$0F		; "wrap" it
	*ora #$20		;
	std >lbptr		save source ptr
	bra gbcp		return byte

*screenloc
*	zmb 2			address on screen
*	align 8			screen has to be aligned on 8 byte boundary
*screen	zmb 40*24*2		40 column by 24 row screen
*screenend
*outstr	pshs a,u
*!	lda ,u+
*	beq >
*	bsr outchr
*	bra <
*!	puls a,u,pc
*outchr	pshs d,x,y,u
*	ldx >screenloc
*	cmpa #13
*	beq outchr1
*	sta ,x++
*	cmpx #screenend
*	blo outchr2
*	ldx #screen+80
*!	ldd ,x++
*	std -82,x
*	cmpx #screenend
*	blo <
*	lda #32
*!	sta ,--x
*	cmpx #screenend-80
*	bhi <
*outchr2	stx >screenloc
*	puls d,x,y,u,pc
*outchr1	ldx #screen
*!	leax 80,x
*	cmpx >screenloc
*	bls <
*	ldu >screenloc
*	stx >screenloc
*	leax ,u
*	lda #32
*!	sta ,x++
*	cmpx >screenloc
*	blo <
*	bra outchr2
*outhex	pshs a,b
*	tfr b,a
*	lsra
*	lsra
*	lsra
*	lsra
*	andb #15
*	addd #$3030
*	cmpa #$39
*	bls >
*	adda #7
*!	cmpb #$39
*	bls >
*	addb #7
*!	jsr outchr
*	tfr b,a
*	jsr outchr
*	puls a,b,pc
*startmess
*	fcc 'Starting kernel loader'
*	fcb 13,13,0
*blockmess
*	fcc 'block'
*	fcb 13,0
*execmess
*	fcc 'exec'
*	fcb 13,0
payload	equ *			kernel starts here

