* uncompress driver
*
* D -> MMU segments with compressed data
*

DRIVER
 PSHS CC
 ORCC #$50	* turn off interrupts
 STD $FFA0	* map in compressed data 
 STD $FFA8
 LDU #0
T@
 LDX ,U++	* screen address for row
 CMPX #$FFFF	* end of compressed data?
 BEQ X@
L@
 LDB ,U+	* first byte
 CMPB #$FF	* end of row?
 BEQ T@
 TSTB		* one or two byte token?
 BLT BYTE2
BYTE1		* one byte token
 BSR CVERT	* convert token to data
 STB ,X+	* write to screen
 BRA L@
BYTE2		* two byte token
 ANDB #$7F	* strip off sign bit
 BSR CVERT	* convert token to data
 LDA ,U+	* get run count
R@
 STB ,X+	* write to screen
 DECA		* end of run?
 BNE R@
 BRA L@		* get next token in this row
X@
 LDD #$3839	* map the compressed data back out
 STD $FFA0
 STD $FFA8
 PULS CC,PC	* turn on IRQ and return

* convert token to value
*
* B is token/value
*
CVERT
 PSHS A
 LEAY DTBL,PCR
 CLRA
 LDB D,Y
 PULS A,PC

DTBL
 FCB 000,001,002,003,004,005,006,007,010,012
 FCB 014,016,017,018,021,032,033,034,035,036
 FCB 037,038,039,042,044,046,048,049,050,051
 FCB 052,053,054,055,062,064,066,067,068,069
 FCB 070,071,074,078,080,082,083,084,085,086
 FCB 087,090,094,096,098,099,100,101,102,103
 FCB 106,110,112,114,115,116,117,118,119,122
 FCB 124,126,149,160,162,165,166,170,172,174
 FCB 192,197,198,199,202,204,206,224,226,227
 FCB 228,229,230,231,234,236,238
