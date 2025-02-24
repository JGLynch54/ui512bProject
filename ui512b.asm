;
;			ui512b
;
;--------------------------------------------------------------------------------------------------------------------------------------------------------------
;			File:			ui512b.asm
;			Author:			John G. Lynch
;			Legal:			Copyright @2024, per MIT License below
;			Date:			June 11, 2024
;
;			Notes:
;				ui512 is a small project to provide basic operations for a variable type of unsigned 512 bit integer.
;
;				ui512a provides basic operations: zero, copy, compare, add, subtract.
;				ui512b provides basic bit-oriented operations: shift left, shift right, and, or, not, least significant bit and most significant bit.
;				ui512md provides multiply and divide.
;
;				It is written in assembly language, using the MASM (ml64) assembler provided as an option within Visual Studio.
;				(currently using VS Community 2022 17.9.6)
;
;				It provides external signatures that allow linkage to C and C++ programs,
;				where a shell/wrapper could encapsulate the methods as part of an object.
;
;				It has assembly time options directing the use of Intel processor extensions: AVX4, AVX2, SIMD, or none:
;				(Z (512), Y (256), or X (128) registers, or regular Q (64bit)).
;
;				If processor extensions are used, the caller must align the variables declared and passed
;				on the appropriate byte boundary (e.g. align as 64 for 512)
;
;				This module is very light-weight (less than 2K bytes) and relatively fast,
;				but is not intended for all processor types or all environments. 
;
;				Use for private (hobbyist), or instructional, or as an example for more ambitious projects is all it is meant to be.
;
;--------------------------------------------------------------------------------------------------------------------------------------------------------------
;
;			MIT License
;
;			Copyright (c) 2024 John G. Lynch
;
;				Permission is hereby granted, free of charge, to any person obtaining a copy
;				of this software and associated documentation files (the "Software"), to deal
;				in the Software without restriction, including without limitation the rights
;				to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
;				copies of the Software, and to permit persons to whom the Software is
;				furnished to do so, subject to the following conditions:
;
;				The above copyright notice and this permission notice shall be included in all
;				copies or substantial portions of the Software.
;
;				THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
;				IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
;				FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
;				AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
;				LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
;				OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
;				SOFTWARE.
;
;--------------------------------------------------------------------------------------------------------------------------------------------------------------

				INCLUDE			ui512aMacros.inc
				INCLUDE			ui512bMacros.inc
				OPTION			casemap:none
.CONST

aligned64		SEGMENT         ALIGN (64)
qOnes			QWORD           8 DUP (0ffffffffffffffffh)
aligned64		ENDS

.CODE			ui512b
				OPTION          PROLOGUE:none
				OPTION          EPILOGUE:none

				MemConstants
;--------------------------------------------------------------------------------------------------------------------------------------------------------------
;			shr_u		-	shift supplied source 512bit (8 QWORDS) right, put in destination
;			Prototype:		void shr_u( u64* destination, u64* source, u32 bits_to_shift)
;			destination	-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			source		-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RDX)
;			bits		-	Number of bits to shift. Will fill with zeros, truncate those shifted out (in R8W)
;			returns		-	nothing (0)
;			Note: unwound loop(s). More instructions, but fewer executed (no loop save, setup, compare loop), faster, fewer regs used

shr_u			PROC			PUBLIC

				CheckAlign		RCX
				CheckAlign		RDX

				CMP				R8W, 0							; handle edge case, shift zero bits
				JNE				@F
				CMP				RCX, RDX
				JE				@@ret							; destination is the same as the source: no copy needed
				Copy512			RCX, RDX						; no shift, just copy (destination, source already in regs)
				JMP				@@ret
@@:
				CMP				R8W, 512						; handle edge case, shift 512 or more bits
				JL				@F
				Zero512			RCX								; zero destination
				JMP				@@ret
@@:

	IF	__UseZ
				VMOVDQA64		ZMM31, ZM_PTR [ RDX ]			; load the 8 qwords into zmm reg (note: word order)
				MOVZX			RAX, R8W
				AND				AX, 03fh						; limit shift count to 63 (shifting bits only here, not words)
				JZ				@F								; must be multiple of 64 bits to shift, no bits, just words to shift
				VPBROADCASTQ	ZMM29, RAX						; Nr bits to shift right
				VPXORQ			ZMM28, ZMM28, ZMM28				; 
				VALIGNQ			ZMM30, ZMM31, ZMM28, 7			; shift copy of words left one word (to get low order bits aligned for shift)
				VPSHRDVQ		ZMM31, ZMM30, ZMM29				; shift, concatenating low bits of next word with each word to shift in
@@:
; with the bits shifted within the words, if the desired shift is more than 64 bits, word shifts are required
; verify Nr of word shift is zero to seven, use it as index into jump table; jump to appropriate shift
				SHR				R8W, 6							; divide Nr bits to shift by 64 giving Nr words to shift
				AND				R8, 07h							; probably not necessary, but ensures a number 0 to 7 for jump table
				SHL				R8W, 3							; multiply by 8 to give QWORD index into jump table
				LEA				RAX, @jt						; address of jump table
				ADD				R8, RAX							; add index
				JMP				Q_PTR [ R8 ]					; jump to routine that shifts the appropriate Nr words
@jt:
				QWORD			@@E, @@1, @@2, @@3, @@4, @@5, @@6, @@7
@@1:			VALIGNQ			ZMM31, ZMM31, ZMM28, 7			; shifts words in ZMM31 right 7, fills with zero, resulting seven plus filled zero to ZMM31
				JMP				@@E
@@2:			VALIGNQ			ZMM31, ZMM31, ZMM28, 6
				JMP				@@E
@@3:			VALIGNQ			ZMM31, ZMM31, ZMM28, 5
				JMP				@@E
@@4:			VALIGNQ			ZMM31, ZMM31, ZMM28, 4
				JMP				@@E
@@5:			VALIGNQ			ZMM31, ZMM31, ZMM28, 3
				JMP				@@E
@@6:			VALIGNQ			ZMM31, ZMM31, ZMM28, 2
				JMP				@@E
@@7:			VALIGNQ			ZMM31, ZMM31, ZMM28, 1

@@E:			VMOVDQA64		ZM_PTR [ RCX ], ZMM31			; store result at callers destination
@@ret:
				RET	

	ELSE

;	save non-volatile regs to be used as work regs			
				PUSH			R12
				PUSH			R13
				PUSH			R14
				PUSH			R15
				PUSH			RDI
				PUSH			RCX
;	load sequential regs with source 8 qwords
				MOV				R9, [RDX + 0 * 8]
				MOV				R10, [RDX + 1 * 8]
				MOV				R11, [RDX + 2 * 8]
				MOV				R12, [RDX + 3 * 8]
				MOV				R13, [RDX + 4 * 8]
				MOV				R14, [RDX + 5 * 8]
				MOV				R15, [RDX + 6 * 8]
				MOV				RDI, [RDX + 7 * 8]
;	determine if / how many bits to shift
				MOVZX			RCX, R8W
				AND				CX, 03fh
				JZ				@@nobits
				MOV				RAX, 64
				SUB				AX, CX
				MOV				CL, AL						; CL left shift Nr
				XCHG			CL, CH
				MOV				CL, R8B						; CH right shift Nr
				AND				CL, 03fh
				XCHG			CL, CH
;
;	Each word is shifted right, and the bits falling out are ORd into the next word.
;	CL holds the number of bits to shift right, CH holds the complement for left shift.
;	The CL register is used for the bit shift number, it is "XCHG" swapped with CH for the left or right shift
;
				MOV				RDX, R15					; Get the sixth word (of 0 to 7)
				SHL				RDX, CL						; shift it left by 64 - bits to shift, putting last bits at high end of register
				XCHG			CH, CL						; switch CL from bits to shift left, to bits to shift right
				SHR				RDI, CL						; Shift the seventh (of 0 to 7) word right, truncating "bottom" bits
				XCHG			CH, CL						; restore CL to the left shift number
				OR				RDI, RDX					; "OR" in the high bits from the 6th word into the shifted seventh word
				;  . . . repeat for each word . . 
				MOV				RDX, R14
				SHL				RDX, CL
				XCHG			CH, CL
				SHR				R15, CL
				XCHG			CH, CL
				OR				R15, RDX
				;
				MOV				RDX, R13
				SHL				RDX, CL
				XCHG			CH, CL
				SHR				R14, CL
				XCHG			CH, CL
				OR				R14, RDX
				;
				MOV				RDX, R12
				SHL				RDX, CL
				XCHG			CH, CL
				SHR				R13, CL
				XCHG			CH, CL
				OR				R13, RDX
				;
				MOV				RDX, R11
				SHL				RDX, CL
				XCHG			CH, CL
				SHR				R12, CL
				XCHG			CH, CL
				OR				R12, RDX
				;
				MOV				RDX, R10
				SHL				RDX, CL
				XCHG			CH, CL
				SHR				R11, CL
				XCHG			CH, CL
				OR				R11, RDX
				;
				MOV				RDX, R9
				SHL				RDX, CL
				XCHG			CH, CL
				SHR				R10, CL
				OR				R10, RDX
				; no bits to OR in on the index 0 (high order) word, just shift it.
				SHR				R9, CL
@@nobits:
				; with the bits shifted within the words, if the desired shift is more than 64 bits, word shifts are required
				; verify Nr of word shift is zero to seven, use it as index into jump table; jump to appropriate shift
				SHR				R8W, 6
				AND				R8, 07h 
				SHL				R8W, 3
				LEA				RAX, jtbl
				ADD				R8, RAX
				XOR				RAX, RAX					; clear rax for use as zeroing words shifted "in"
				POP				RCX							; restore RCX, destination address
				JMP				Q_PTR [ R8 ]
jtbl:
				QWORD			S0, S1, S2, S3, S4, S5, S6, S7
S0:				; no word shift, just bits, so store words in destination in the same order as they are
				MOV				[RCX + 0 * 8], R9
				MOV				[RCX + 1 * 8], R10
				MOV				[RCX + 2 * 8], R11
				MOV				[RCX + 3 * 8], R12
				MOV				[RCX + 4 * 8], R13
				MOV				[RCX + 5 * 8], R14
				MOV				[RCX + 6 * 8], R15
				MOV				[RCX + 7 * 8], RDI	
				JMP				@@R
S1:
				MOV				[RCX + 0 * 8], RAX
				MOV				[RCX + 1 * 8], R9
				MOV				[RCX + 2 * 8], R10
				MOV				[RCX + 3 * 8], R11
				MOV				[RCX + 4 * 8], R12
				MOV				[RCX + 5 * 8], R13
				MOV				[RCX + 6 * 8], R14
				MOV				[RCX + 7 * 8], R15	
				JMP				@@R
S2:
				MOV				[RCX + 0 * 8], RAX
				MOV				[RCX + 1 * 8], RAX
				MOV				[RCX + 2 * 8], R9
				MOV				[RCX + 3 * 8], R10
				MOV				[RCX + 4 * 8], R11
				MOV				[RCX + 5 * 8], R12
				MOV				[RCX + 6 * 8], R13
				MOV				[RCX + 7 * 8], R14	
				JMP				@@R

S3:				MOV				[RCX + 0 * 8], RAX
				MOV				[RCX + 1 * 8], RAX
				MOV				[RCX + 2 * 8], RAX
				MOV				[RCX + 3 * 8], R9
				MOV				[RCX + 4 * 8], R10
				MOV				[RCX + 5 * 8], R11
				MOV				[RCX + 6 * 8], R12
				MOV				[RCX + 7 * 8], R13	
				JMP				@@R

S4:				MOV				[RCX + 0 * 8], RAX
				MOV				[RCX + 1 * 8], RAX
				MOV				[RCX + 2 * 8], RAX
				MOV				[RCX + 3 * 8], RAX
				MOV				[RCX + 4 * 8], R9
				MOV				[RCX + 5 * 8], R10
				MOV				[RCX + 6 * 8], R11
				MOV				[RCX + 7 * 8], R12			
				JMP				@@R

S5:				MOV				[RCX + 0 * 8], RAX
				MOV				[RCX + 1 * 8], RAX
				MOV				[RCX + 2 * 8], RAX
				MOV				[RCX + 3 * 8], RAX
				MOV				[RCX + 4 * 8], RAX
				MOV				[RCX + 5 * 8], R9
				MOV				[RCX + 6 * 8], R10
				MOV				[RCX + 7 * 8], R11	
				JMP				@@R

S6:				MOV				[RCX + 0 * 8], RAX
				MOV				[RCX + 1 * 8], RAX
				MOV				[RCX + 2 * 8], RAX
				MOV				[RCX + 3 * 8], RAX
				MOV				[RCX + 4 * 8], RAX
				MOV				[RCX + 5 * 8], RAX
				MOV				[RCX + 6 * 8], R9
				MOV				[RCX + 7 * 8], R10	
				JMP				@@R

S7:				MOV				[RCX + 0 * 8], RAX
				MOV				[RCX + 1 * 8], RAX
				MOV				[RCX + 2 * 8], RAX
				MOV				[RCX + 3 * 8], RAX
				MOV				[RCX + 4 * 8], RAX
				MOV				[RCX + 5 * 8], RAX
				MOV				[RCX + 6 * 8], RAX
				MOV				[RCX + 7 * 8], R9		
@@R:
;	restore non-volatile regs to as-called condition
				POP				RDI
				POP				R15
				POP				R14
				POP				R13
				POP				R12
@@ret:
				RET
	ENDIF
	
shr_u			ENDP


;--------------------------------------------------------------------------------------------------------------------------------------------------------------
;			shl_u		-	shift supplied source 512bit (8 QWORDS) left, put in destination
;			Prototype:		void shl_u( u64* destination, u64* source, u16 bits_to_shift);
;			destination	-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			source		-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RDX)
;			bits		-	Number of bits to shift. Will fill with zeros, truncate those shifted out (in R8W)
;			returns		-	nothing (0)

shl_u			PROC			PUBLIC

				CheckAlign		RCX
				CheckAlign		RDX

				CMP				R8W, 0						; handle edge case, shift zero bits
				JNE				@F
				CMP				RCX, RDX
				JE				@@ret
				Copy512			RCX, RDX					; no shift, just copy (destination, source already in regs)
				JMP				@@ret
@@:
				CMP				R8W, 512					; handle edge case, shift 512 or more bits
				JL				@F
				Zero512			RCX							; zero destination
				JMP				@@ret
@@:

	IF __UseZ
	
				VMOVDQA64		ZMM31, ZM_PTR [ RDX ]		; load the 8 qwords into zmm reg (note: word order)
				MOVZX			RAX, R8W
				AND				AX, 03fh
				JZ				@F							; must be multiple of 64 bits to shift, no bits, just words to shift
;			Do the shift of bits within the 64 bit words
				VPBROADCASTQ	ZMM29, RAX					; Nr bits to shift left
				VPXORQ			ZMM28, ZMM28, ZMM28			; 
				VALIGNQ			ZMM30, ZMM28, ZMM31, 1		; shift copy of words right one word (to get low order bits aligned for shift)
				VPSHLDVQ		ZMM31, ZMM30, ZMM29			; shift, concatentating low bits of next word with each word to shift in
@@:
; with the bits shifted within the words, if the desired shift is more than 64 bits, word shifts are required
; verify Nr of word shift is zero to seven, use it as index into jump table; jump to appropriate shift
				SHR				R8W, 6						; divide Nr bits to shift by 64 giving Nr words to shift
				AND				R8, 07h						; probably not necessary, but ensures a number 0 to 7 for jump table
				SHL				R8W, 3						; multiply by 8 to give QWORD index into jump table
				LEA				RAX, @jt					; address of jump table
				ADD				R8, RAX						; add index
				JMP				Q_PTR [ R8 ]				; jump to routine that shifts the appropriate Nr words
@jt:
				QWORD			@@E, @@1, @@2, @@3, @@4, @@5, @@6, @@7
;			Do the shifts of multiples of 64 bits (words)
@@1:			VALIGNQ			ZMM31, ZMM28, ZMM31, 1
				JMP				@@E
@@2:			VALIGNQ			ZMM31, ZMM28, ZMM31, 2
				JMP				@@E
@@3:			VALIGNQ			ZMM31, ZMM28, ZMM31, 3
				JMP				@@E
@@4:			VALIGNQ			ZMM31, ZMM28, ZMM31, 4
				JMP				@@E
@@5:			VALIGNQ			ZMM31, ZMM28, ZMM31, 5
				JMP				@@E
@@6:			VALIGNQ			ZMM31, ZMM28, ZMM31, 6
				JMP				@@E
@@7:			VALIGNQ			ZMM31, ZMM28, ZMM31, 7

@@E:			VMOVDQA64		ZM_PTR [ RCX ], ZMM31
@@ret:
				RET
				
	ELSE

;	save non-volitile regs to be used as work regs			
				PUSH			R12
				PUSH			R13
				PUSH			R14
				PUSH			R15
				PUSH			RDI
				PUSH			RCX
;	load sequential regs with source 8 qwords
				MOV				R9, [RDX + 0 * 8]
				MOV				R10, [RDX + 1 * 8]
				MOV				R11, [RDX + 2 * 8]
				MOV				R12, [RDX + 3 * 8]
				MOV				R13, [RDX + 4 * 8]
				MOV				R14, [RDX + 5 * 8]
				MOV				R15, [RDX + 6 * 8]
				MOV				RDI, [RDX + 7 * 8]
;	determine if / how many bits to shift
				MOVZX			RCX, R8W
				AND				CX, 03fh
				JZ				@@nobits
				MOV				AX, 64
				SUB				AX, CX
				MOV				CL, AL						; CL right shift Nr
				XCHG			CL, CH
				MOV				CL, R8B						; CH left shift Nr
				AND				CL, 03fh
				XCHG			CL, CH
;
;	Each word is shifted right, and the bits falling out are ORd into the next word.
;	CL holds the number of bits to shift right, CH holds the complement for left shift.
;	The CL register is used for the bit shift number, it is "XCHG" swapped with CH for the left or right shift
;
				MOV				RDX, R10					; Get the first word (of 0 to 7)
				SHR				RDX, CL						; shift it right by 64 - bits to shift, putting first bits at low end of register
				XCHG			CH, CL						; switch CL from bits to shift right, to bits to shift left
				SHL				R9, CL						; Shift the zero (of 0 to 7) word left, truncating "top" bits
				XCHG			CH, CL						; restore CL to the right shift number
				OR				R9, RDX						; "OR" in the low bits from the 6th word into the shifted seventh word
;  . . . repeat for each word . . 
				MOV				RDX, R11
				SHR				RDX, CL
				XCHG			CH, CL
				SHL				R10, CL
				XCHG			CH, CL
				OR				R10, RDX
				;
				MOV				RDX, R12
				SHR				RDX, CL
				XCHG			CH, CL
				SHL				R11, CL
				XCHG			CH, CL
				OR				R11, RDX
				;
				MOV				RDX, R13
				SHR				RDX, CL
				XCHG			CH, CL
				SHL				R12, CL
				XCHG			CH, CL
				OR				R12, RDX
				;
				MOV				RDX, R14
				SHR				RDX, CL
				XCHG			CH, CL
				SHL				R13, CL
				XCHG			CH, CL
				OR				R13, RDX
				;
				MOV				RDX, R15
				SHR				RDX, CL
				XCHG			CH, CL
				SHL				R14, CL
				XCHG			CH, CL
				OR				R14, RDX
				;
				MOV				RDX, RDI
				SHR				RDX, CL
				XCHG			CH, CL
				SHL				R15, CL
				OR				R15, RDX
; no bits to OR in on the index 0 (high order) word, just shift it.
				SHL				RDI, CL
@@nobits:
; with the bits shifted within the words, if the desired shift is more than 64 bits, word shifts are required
; verify Nr of word shift is zero to seven, use it as index into jump table; jump to appropriate shift
				SHR				R8W, 6
				AND				R8, 07h 
				SHL				R8W, 3
				LEA				RAX, jtbl
				ADD				R8, RAX
				XOR				RAX, RAX					; clear rax for use as zeroing words shifted "in"
				POP				RCX							; restore RCX, destination address
				JMP				Q_PTR [ R8 ]
jtbl:
				QWORD			@@0, @@1, @@2, @@3, @@4, @@5, @@6, @@7
; no word shift, just bits, so store words in destination in the same order as they are
@@0:			
				MOV				[RCX + 0 * 8], R9
				MOV				[RCX + 1 * 8], R10
				MOV				[RCX + 2 * 8], R11
				MOV				[RCX + 3 * 8], R12
				MOV				[RCX + 4 * 8], R13
				MOV				[RCX + 5 * 8], R14
				MOV				[RCX + 6 * 8], R15
				MOV				[RCX + 7 * 8], RDI	
				JMP				@@R
; one word shift, shifting one word (64+ bits) so store words in destination shifted left one, fill with zero
@@1:			
				MOV				[RCX + 0 * 8], R10
				MOV				[RCX + 1 * 8], R11
				MOV				[RCX + 2 * 8], R12
				MOV				[RCX + 3 * 8], R13
				MOV				[RCX + 4 * 8], R14
				MOV				[RCX + 5 * 8], R15
				MOV				[RCX + 6 * 8], RDI
				MOV				[RCX + 7 * 8], RAX	
				JMP				@@R
; two word shift
@@2:			
				MOV				[RCX + 0 * 8], R11
				MOV				[RCX + 1 * 8], R12
				MOV				[RCX + 2 * 8], R13
				MOV				[RCX + 3 * 8], R14
				MOV				[RCX + 4 * 8], R15
				MOV				[RCX + 5 * 8], RDI
				MOV				[RCX + 6 * 8], RAX
				MOV				[RCX + 7 * 8], RAX	
				JMP				@@R
; three word shift
@@3:			
				MOV				[RCX + 0 * 8], R12
				MOV				[RCX + 1 * 8], R13
				MOV				[RCX + 2 * 8], R14
				MOV				[RCX + 3 * 8], R15
				MOV				[RCX + 4 * 8], RDI
				MOV				[RCX + 5 * 8], RAX
				MOV				[RCX + 6 * 8], RAX
				MOV				[RCX + 7 * 8], RAX	
				JMP				@@R
; four word shift
@@4:			
				MOV				[RCX + 0 * 8], R13
				MOV				[RCX + 1 * 8], R14
				MOV				[RCX + 2 * 8], R15
				MOV				[RCX + 3 * 8], RDI
				MOV				[RCX + 4 * 8], RAX
				MOV				[RCX + 5 * 8], RAX
				MOV				[RCX + 6 * 8], RAX
				MOV				[RCX + 7 * 8], RAX	
				JMP				@@R
; five word shift
@@5:			
				MOV				[RCX + 0 * 8], R14
				MOV				[RCX + 1 * 8], R15
				MOV				[RCX + 2 * 8], RDI
				MOV				[RCX + 3 * 8], RAX
				MOV				[RCX + 4 * 8], RAX
				MOV				[RCX + 5 * 8], RAX
				MOV				[RCX + 6 * 8], RAX
				MOV				[RCX + 7 * 8], RAX	
				JMP				@@R
; six word shift
@@6:			
				MOV				[RCX + 0 * 8], R15
				MOV				[RCX + 1 * 8], RDI
				MOV				[RCX + 2 * 8], RAX
				MOV				[RCX + 3 * 8], RAX
				MOV				[RCX + 4 * 8], RAX
				MOV				[RCX + 5 * 8], RAX
				MOV				[RCX + 6 * 8], RAX
				MOV				[RCX + 7 * 8], RAX	
				JMP				@@R
; seven word shift
@@7:			
				MOV				[RCX + 0 * 8], RDI
				MOV				[RCX + 1 * 8], RAX
				MOV				[RCX + 2 * 8], RAX
				MOV				[RCX + 3 * 8], RAX
				MOV				[RCX + 4 * 8], RAX
				MOV				[RCX + 5 * 8], RAX
				MOV				[RCX + 6 * 8], RAX
				MOV				[RCX + 7 * 8], RAX
;	restore non-volitile regs to as-called condition
@@R:		
				POP				RDI
				POP				R15
				POP				R14
				POP				R13
				POP				R12
@@ret:
				RET

	ENDIF

shl_u			ENDP


;--------------------------------------------------------------------------------------------------------------------------------------------------------------
;			and_u		-	logical 'AND' bits in lh_op, rh_op, put result in destination
;			Prototype:		void and_u( u64* destination, u64* lh_op, u64* rh_op);
;			destination	-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			lh_op		-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RDX)
;			rh_op		-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in R8)
;			returns		-	nothing (0)
and_u			PROC			PUBLIC 

				CheckAlign		RCX
				CheckAlign		RDX
				CheckAlign		R8

	IF __UseZ
	
				VMOVDQA64		ZMM31, ZM_PTR [ RDX ]		; load lh_op	
				VPANDQ			ZMM31, ZMM31, ZM_PTR [ R8 ]	; 'AND' with rh_op
				VMOVDQA64		ZM_PTR [ RCX ], ZMM31		; store at destination address

	ELSEIF __UseY

				VMOVDQA64		YMM4, YM_PTR [ RDX + 0 * 8 ]
				VPANDQ			YMM5, YMM4, YM_PTR [ R8 + 0 * 8 ]
				VMOVDQA64		YM_PTR [ RCX + 0 * 8 ], YMM5
				VMOVDQA64		YMM2, YM_PTR [ RDX + 4 * 8 ]
				VPANDQ			YMM3, YMM2, YM_PTR [ R8 + 4 * 8]
				VMOVDQA64		YM_PTR [ RCX + 4 * 8 ], YMM3

	ELSEIF __UseX

				MOVDQA			XMM4, XM_PTR [ RDX + 0 * 8 ]
				PAND			XMM4, XM_PTR [ R8 + 0 * 8]
				MOVDQA			XM_PTR [ RCX + 0 * 8 ], XMM4
				MOVDQA			XMM5, XM_PTR [ RDX + 2 * 8 ]
				PAND			XMM5, XM_PTR [ R8 + 2 * 8]
				MOVDQA			XM_PTR [ RCX + 2 * 8 ], XMM5
				MOVDQA			XMM4, XM_PTR [ RDX + 4 * 8 ]
				PAND			XMM4, XM_PTR [ R8 + 4 * 8]
				MOVDQA			XM_PTR [ RCX + 4 * 8 ], XMM4
				MOVDQA			XMM5, XM_PTR [ RDX + 6 * 8 ]
				PAND			XMM5, XM_PTR [ R8 + 6 * 8]
				MOVDQA			XM_PTR [ RCX + 6 * 8 ], XMM5

	ELSE

				MOV				RAX, [ RDX + 0 * 8 ]
				AND				RAX, [ R8 + 0 * 8 ]
				MOV				[ RCX + 0 * 8 ], RAX
				MOV				RAX, [ RDX + 1 * 8 ]
				AND				RAX, [ R8 + 1 * 8 ]
				MOV				[ RCX + 1 * 8 ], RAX
				MOV				RAX, [ RDX + 2 * 8 ]
				AND				RAX, [ R8 + 2 * 8 ]
				MOV				[ RCX + 2 * 8 ], RAX
				MOV				RAX, [ RDX + 3 * 8 ]
				AND				RAX, [ R8 + 3 * 8 ]
				MOV				[ RCX + 3 * 8 ], RAX
				MOV				RAX, [ RDX + 4 * 8 ]
				AND				RAX, [ R8 + 4 * 8 ]
				MOV				[ RCX + 4 * 8 ], RAX
				MOV				RAX, [ RDX + 5 * 8 ]
				AND				RAX, [ R8 + 5 * 8 ]
				MOV				[ RCX + 5 * 8 ], RAX			
				MOV				RAX, [ RDX + 6 * 8 ]
				AND				RAX, [ R8 + 6 * 8 ]
				MOV				[ RCX + 6 * 8 ], RAX
				MOV				RAX, [ RDX + 7 * 8 ]
				AND				RAX, [ R8 + 7 * 8 ]
				MOV				[ RCX + 7 * 8 ], RAX

	ENDIF

				RET		
and_u			ENDP

;--------------------------------------------------------------------------------------------------------------------------------------------------------------
;			or_u		-	logical 'OR' bits in lh_op, rh_op, put result in destination
;			Prototype:		void or_u( u64* destination, u64* lh_op, u64* rh_op);
;			destination	-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			lh_op		-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RDX)
;			rh_op		-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in R8)
;			returns		-	nothing (0)

or_u			PROC			PUBLIC

				CheckAlign		RCX
				CheckAlign		RDX
				CheckAlign		R8

	IF __UseZ
	
				VMOVDQA64		ZMM31, ZM_PTR [ RDX ]			
				VPORQ			ZMM31, ZMM31, ZM_PTR [ R8 ]
				VMOVDQA64		ZM_PTR [ RCX ], ZMM31

	ELSEIF __UseY

				VMOVDQA64		YMM4, YM_PTR [ RDX + 0 * 8 ]
				VPORQ			YMM5, YMM4, YM_PTR [ R8 + 0 * 8 ]
				VMOVDQA64		YM_PTR [ RCX + 0 * 8 ], YMM5
				VMOVDQA64		YMM2, YM_PTR [ RDX + 4 * 8 ]
				VPORQ			YMM3, YMM2, YM_PTR [ R8 + 4 * 8]
				VMOVDQA64		YM_PTR [ RCX + 4 * 8 ], YMM3

	ELSEIF __UseX

				MOVDQA			XMM4, XM_PTR [ RDX + 0 * 8 ]
				POR				XMM4, XM_PTR [ R8 + 0 * 8]
				MOVDQA			XM_PTR [ RCX + 0 * 8 ], XMM4
				MOVDQA			XMM5, XM_PTR [ RDX + 2 * 8 ]
				POR				XMM5, XM_PTR [ R8 + 2 * 8]
				MOVDQA			XM_PTR [ RCX + 2 * 8 ], XMM5
				MOVDQA			XMM4, XM_PTR [ RDX + 4 * 8 ]
				POR				XMM4, XM_PTR [ R8 + 4 * 8]
				MOVDQA			XM_PTR [ RCX + 4 * 8 ], XMM4
				MOVDQA			XMM5, XM_PTR [ RDX + 6 * 8 ]
				POR				XMM5, XM_PTR [ R8 + 6 * 8]
				MOVDQA			XM_PTR [ RCX + 6 * 8 ], XMM5

	ELSE

				MOV				RAX, [ RDX + 0 * 8 ]
				OR				RAX,  [ R8 + 0 * 8 ]
				MOV				[ RCX + 0 * 8 ], RAX
				MOV				RAX, [ RDX + 1 * 8 ]
				OR				RAX, [ R8 + 1 * 8 ]
				MOV				[ RCX + 1 * 8 ], RAX
				MOV				RAX, [ RDX + 2 * 8 ]
				OR				RAX, [ R8 + 2 * 8 ]
				MOV				[ RCX + 2 * 8 ], RAX
				MOV				RAX, [ RDX + 3 * 8 ]
				OR				RAX, [ R8 + 3 * 8 ]
				MOV				[ RCX + 3 * 8 ], RAX
				MOV				RAX, [ RDX + 4 * 8 ]
				OR				RAX, [ R8 + 4 * 8 ]
				MOV				[ RCX + 4 * 8 ], RAX
				MOV				RAX, [ RDX + 5 * 8 ]
				OR				RAX, [ R8 + 5 * 8 ]
				MOV				[ RCX + 5 * 8 ], RAX			
				MOV				RAX, [ RDX + 6 * 8 ]
				OR				RAX, [ R8 + 6 * 8 ]
				MOV				[ RCX + 6 * 8 ], RAX
				MOV				RAX, [ RDX + 7 * 8 ]
				OR				RAX, [ R8 + 7 * 8 ]
				MOV				[ RCX + 7 * 8 ], RAX

	ENDIF

				RET 
or_u			ENDP


;--------------------------------------------------------------------------------------------------------------------------------------------------------------
;			not_u		-	logical 'NOT' bits in source, put result in destination
;			Prototype:		void not_u( u64* destination, u64* source);
;			destination	-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			source		-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RDX)
;			returns		-	nothing (0)

not_u			PROC			PUBLIC

				CheckAlign		RCX
				CheckAlign		RDX

	IF __UseZ
	
				VMOVDQA64		ZMM31, ZM_PTR [RDX]			
				VPANDNQ			ZMM31, ZMM31, qOnes			; qOnes (declared in the data section of this module) is 8 QWORDS, binary all ones
				VMOVDQA64		ZM_PTR [RCX], ZMM31

	ELSEIF __UseY

				VMOVDQA64		YMM4, YM_PTR [ RDX + 0 * 8 ]
				VPANDNQ			YMM5, YMM4, qOnes
				VMOVDQA64		YM_PTR [ RCX + 0 * 8 ], YMM5
				VMOVDQA64		YMM4, YM_PTR [ RDX + 4 * 8 ]
				VPANDNQ			YMM5, YMM4, qOnes
				VMOVDQA64		YM_PTR [ RCX + 4 * 8 ], YMM5

	ELSEIF __UseX

				MOVDQA			XMM4, XM_PTR [ RDX + 0 * 8 ]
				PANDN			XMM4, XM_PTR qOnes
				MOVDQA			XM_PTR [ RCX + 0 * 8 ], XMM4
				MOVDQA			XMM4, XM_PTR [ RDX + 2 * 8 ]
				PANDN			XMM4, XM_PTR qOnes
				MOVDQA			XM_PTR [ RCX + 2 * 8 ], XMM4
				MOVDQA			XMM4, XM_PTR [ RDX + 4 * 8 ]
				PANDN			XMM4, XM_PTR qOnes
				MOVDQA			XM_PTR [ RCX + 4 * 8 ], XMM4
				MOVDQA			XMM4, XM_PTR [ RDX + 6 * 8 ]
				PANDN			XMM4, XM_PTR qOnes
				MOVDQA			XM_PTR [ RCX + 6 * 8 ], XMM4

	ELSE

				MOV				RAX, [ RDX + 0 * 8 ]
				NOT				RAX
				MOV				[ RCX + 0 * 8 ], RAX
				MOV				RAX, [ RDX + 1 * 8 ]
				NOT				RAX
				MOV				[ RCX + 1 * 8 ], RAX
				MOV				RAX, [ RDX + 2 * 8 ]
				NOT				RAX
				MOV				[ RCX + 2 * 8 ], RAX
				MOV				RAX, [ RDX + 3 * 8 ]
				NOT				RAX
				MOV				[ RCX + 3 * 8 ], RAX
				MOV				RAX, [ RDX + 4 * 8 ]
				NOT				RAX
				MOV				[ RCX + 4 * 8 ], RAX
				MOV				RAX, [ RDX + 5 * 8 ]
				NOT				RAX
				MOV				[ RCX + 5 * 8 ], RAX			
				MOV				RAX, [ RDX + 6 * 8 ]
				NOT				RAX
				MOV				[ RCX + 6 * 8 ], RAX
				MOV				RAX, [ RDX + 7 * 8 ]
				NOT				RAX
				MOV				[ RCX + 7 * 8 ], RAX
	ENDIF
				RET	
not_u			ENDP


;--------------------------------------------------------------------------------------------------------------------------------------------------------------
;			msb_u		-	find most significant bit in supplied source 512bit (8 QWORDS)
;			Prototype:		s16 msb_u( u64* source );
;			source		-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			returns		-	-1 if no most significant bit, bit number otherwise, bits numbered 0 to 511 inclusive
;			Note:	a returned zero means the significant bit is bit0 of the eighth word of the 512bit source parameter; (the right most bit)
;					a returned 511 means bit63 of the first word (the left most bit)

msb_u			PROC			PUBLIC
				
				CheckAlign		RCX

	IF __UseZ

				VMOVDQA64		ZMM31, ZM_PTR [RCX]			; Load source 
				VPTESTMQ		K1, ZMM31, ZMM31			; find non-zero words (if any)
				KMOVB			EAX, K1
				CMP				EAX, 0						; exit with -1 if all eight qwords are zero (no significant bit)
				JE				@@zero
				BSF				ECX, EAX					; determine index of word from first non-zero bit in mask
				MOV				RAX, 7
				SUB				RAX, RCX					; convert index to offset
				SHL				RAX, 6
				VPCOMPRESSQ		ZMM0 {k1}{z}, ZMM31
				VMOVQ			RCX, XMM0					; extract the non-zero word
				BSR				RCX, RCX					; get the index of the non-zero bit within the word
				ADD				RAX, RCX					; Word index * 64 + bit index becomes bit index to first non-zero bit (0 to 511, where )
				RET
@@zero:
				MOV				EAX, -1
				RET
	ELSE

				PUSH			R10
				PUSH			R11
				MOV				R10, -1						; Initialize loop counter (and index)
@@NextWord:
				INC				R10D
				CMP				R10D, 8
				JNZ				@F							; Loop through values 0 to 7, then exit
				MOV				EAX, -1
				JMP				@@Finished
@@:
				BSR				RAX, [ RCX + R10 * 8 ]		; Reverse Scan indexed word for significant bit
				JZ				@@NextWord					; None found, loop to next word
				MOV				R11D, 7
				SUB				R11D, R10D					; calculate seven minus the word index (which word has the msb?)
				SHL				R11D, 6						; times 64 for each word
				ADD				EAX, R11D					; plus the BSR found bit position within the word yields the bit position within the 512 bit source
@@Finished:
				POP				R11
				POP				R10
				RET	
	ENDIF
msb_u			ENDP

;--------------------------------------------------------------------------------------------------------------------------------------------------------------
;			lsb_u		-	find least significant bit in supplied source 512bit (8 QWORDS)
;			Prototype:		s16 lsb_u( u64* source );
;			source		-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			returns		-	-1 if no least significant bit, bit number otherwise, bits numbered 0 to 511 inclusive
;			Note:	a returned zero means the significant bit is bit0 of the eighth word of the 512bit source parameter; (the right most bit)
;					a returned 511 means bit63 of the first word (the left most bit)

lsb_u			PROC			PUBLIC
				
				CheckAlign		RCX

	IF __UseZ
				Push			R9
				VMOVDQA64		ZMM31, ZM_PTR [RCX]			; Load source 
				VPTESTMQ		K1, ZMM31, ZMM31			; find non-zero words (if any)
				KMOVB			EAX, K1
				CMP				EAX, 0						; exit with -1 if all eight qwords are zero (no significant bit)
				JE				@@zero
				BSR				ECX, EAX					; determine index of word from last non-zero bit in mask
				MOV				RAX, 7
				SUB				RAX, RCX					; convert index to offset
				SHL				RAX, 6
				XOR				R9, R9
				INC				R9
				SHL				R9, CL
				KMOVB			K2, R9
				VPCOMPRESSQ		ZMM0 {k2}{z}, ZMM31
				VMOVQ			RCX, XMM0					; extract the non-zero word
				BSR				RCX, RCX					; get the index of the non-zero bit within the word
				ADD				RAX, RCX					; Word index * 64 + bit index becomes bit index to first non-zero bit (0 to 511, where )
				JMP				@ret
@@zero:
				MOV				EAX, -1
@ret:
				POP				R9
				RET
	ELSE

				PUSH			R10
				PUSH			R11
				MOV				R10, 8						; Initialize loop counter (and index)
@@NextWord:
				DEC				R10D
				CMP				R10D, -1
				JNE				@F							; Loop through values 7 to 0, then exit
				MOV				EAX, -1
				JMP				@@Finished
@@:
				BSF				RAX, [ RCX + R10 * 8 ]		; Scan indexed word for significant bit
				JZ				@@NextWord					; None found, loop to next word
				MOV				R11D, 7						;  
				SUB				R11D, R10D					; calculate seven minus the word index (which word has the msb?)
				SHL				R11D, 6						; times 64 for each word
				ADD				EAX, R11D					; plus the BSF found bit position within the word yields the bit position within the 512 bit source
@@Finished:
				POP				R11
				POP				R10
				RET
	ENDIF
lsb_u			ENDP



END