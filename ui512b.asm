IFNDEF			legalnotes
legalnotes		EQU				1
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
;				(currently using VS Community 2022 17.14.10)
;
;				It provides external signatures that allow linkage to C and C++ programs,
;				where a shell/wrapper could encapsulate the methods as part of an object.
;
;				It has assembly time options directing the use of Intel processor extensions: AVX4, AVX2, SIMD, or none:
;				(Z (512), Y (256), or X (128) registers, or regular Q (64bit)).
;
;				Note: The file "compile_time_options.inc" contains the options that can be configured for extension usage, and other options.
;
;				If processor extensions are used, the caller must align the variables declared and passed
;				on the appropriate byte boundary (e.g. align as 64 for 512)
;
;				This module is very light-weight (less than 2K bytes) and relatively fast,
;				but is not intended for all processor types or all environments. 
;
;				Use for private (hobbyist), or instructional, or as an example for more ambitious projects.
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
ENDIF			; legal notes

				INCLUDE			compile_time_options.inc
				INCLUDE			ui512aMacros.inc
				INCLUDE			ui512bMacros.inc
				OPTION			casemap:none

ui512D			SEGMENT			'DATA'	ALIGN (64)				; Declare a data segment. Aligned 64.	
				MemConstants									; Generate memory resident constants
ui512D			ENDS											; end of data segment


;--------------------------------------------------------------------------------------------------------------------------------------------------------------
;			shr_u		-	shift supplied source 512bit (8 QWORDS) right, put in destination
;			Prototype:		void shr_u( u64* destination, u64* source, u32 bits_to_shift)
;			destination	-	Address of 64 byte aligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			source		-	Address of 64 byte aligned array of 8 64-bit words (QWORDS) 512 bits (in RDX)
;			bits		-	Number of bits to shift. Will fill with zeros, truncate those shifted out (in R8W)
;			returns		-	nothing (0)
;			Note: unwound loop(s). More instructions, but fewer executed (no loop save, setup, compare loop), faster, fewer regs used

				Leaf_Entry		shr_u, ui512
				CheckAlign		RCX								; (OUT) destination of shifted 8 QWORDs
				CheckAlign		RDX								; (IN)	source of 8 QWORDS

				CMP				R8W, 512						; handle edge case, shift 512 or more bits
				JL				@F
				Zero512			RCX								; zero destination
				RET
@@:
				AND				R8, 511							; ensure no high bits above shift count
				JNZ				@F								; handle edge case, zero bits to shift
				CMP				RCX, RDX
				JE				@@ret							; destination is the same as the source: no copy needed
				Copy512			RCX, RDX						; no shift, just copy (destination, source already in regs)
@@ret:
				RET
@@:

	IF	__UseZ
				VMOVDQA64		ZMM31, ZM_PTR [ RDX ]			; load the 8 qwords into zmm reg (note: word order)
				LEA				RAX, [ R8 ]
				AND				AX, 03fh						; limit shift count to 63 (shifting bits only here, not words)
				JZ				@F								; if true, must be multiple of 64 bits to shift, no bits, just words to shift
				VPBROADCASTQ	ZMM29, RAX						; Nr bits to shift right
				VPXORQ			ZMM28, ZMM28, ZMM28				; 
				VALIGNQ			ZMM30, ZMM31, ZMM28, 7			; shift copy of words left one word (to get low order bits aligned for shift)
				VPSHRDVQ		ZMM31, ZMM30, ZMM29				; shift, concatenating low bits of next word with each word to shift in
@@:

; with the bits shifted within the words, if the desired shift is more than 64 bits, word shifts are required
; verify Nr of word shift is zero to seven, use it as index into jump table; jump to appropriate shift
				SHR				R8W, 6							; divide Nr bits to shift by 64 giving Nr words to shift (can only be 0-7 based on above validation)
				LEA				RAX, @jt						; address of jump table
				JMP				Q_PTR [ RAX ] [ R8 * 8 ]		; jump to routine that shifts the appropriate Nr words
@jt:
				QWORD			@@E, @@1, @@2, @@3, @@4, @@5, @@6, @@7
@@1:			VALIGNQ			ZMM31, ZMM31, ZMM28, 7			; shifts words in ZMM31 right 7, fills with zero, resulting seven plus filled zero to ZMM31
@@E:			VMOVDQA64		ZM_PTR [ RCX ], ZMM31			; store result at callers destination
				RET

@@2:			VALIGNQ			ZMM31, ZMM31, ZMM28, 6
				VMOVDQA64		ZM_PTR [ RCX ], ZMM31			; store result at callers destination
				RET

@@3:			VALIGNQ			ZMM31, ZMM31, ZMM28, 5
				VMOVDQA64		ZM_PTR [ RCX ], ZMM31			; store result at callers destination
				RET

@@4:			VALIGNQ			ZMM31, ZMM31, ZMM28, 4
				VMOVDQA64		ZM_PTR [ RCX ], ZMM31			; store result at callers destination
				RET

@@5:			VALIGNQ			ZMM31, ZMM31, ZMM28, 3
				VMOVDQA64		ZM_PTR [ RCX ], ZMM31			; store result at callers destination
				RET

@@6:			VALIGNQ			ZMM31, ZMM31, ZMM28, 2
				VMOVDQA64		ZM_PTR [ RCX ], ZMM31			; store result at callers destination
				RET

@@7:			VALIGNQ			ZMM31, ZMM31, ZMM28, 1
				VMOVDQA64		ZM_PTR [ RCX ], ZMM31			; store result at callers destination
				RET	

	ELSE

;	save non-volatile regs to be used as work regs			
				PUSH			R12								; going to use 8 gp regs for the 8 qword source
				PUSH			R13								; R9, R10, R11 are considered 'volatile' and dont need to be saved
				PUSH			R14								; R12, R13, R14, R15, RDI must be returned to caller with current values. Save them
				PUSH			R15
				PUSH			RDI
				PUSH			RCX								; need current value of RCX (dest), but also need to use the reg. Save it
				PUSH			RBX								; non-volatile, need the reg, so save the value

;	load sequential regs with source 8 qwords
				MOV				R9, Q_PTR [ RDX ] [ 0 * 8 ]		; R9 holds source at index [0], most significant qword
				MOV				R10, Q_PTR [ RDX ] [ 1 * 8 ]	; R10 <- [1]
				MOV				R11, Q_PTR [ RDX ] [ 2 * 8 ]	; R11 <- [2]
				MOV				R12, Q_PTR [ RDX ] [ 3 * 8 ]	; R12 <- [3]
				MOV				R13, Q_PTR [ RDX ] [ 4 * 8 ]	; R13 <- [4]
				MOV				R14, Q_PTR [ RDX ] [ 5 * 8 ]	; R14 <- [5]
				MOV				R15, Q_PTR [ RDX ] [ 6 * 8 ]	; R15 <- [6]
				MOV				RDI, Q_PTR [ RDX ] [ 7 * 8 ]	; RDI holds source at index [7], least significant qword

;	determine if / how many bits to shift

				LEA				RCX, [ R8 ]						; R8 still carries users shift count.
				AND				RCX, 03Fh						; Mask down to Nr of bits to shift right -> RCX
				JZ				@@nobits						; might be word shifts, but no bit shifts required
				LEA				RBX, [ 64 ]
				SUB				RBX, RCX						; Nr to shift left -> RBX
;
;	Each word is shifted right, and the bits shifted out are ORd into the next (less significant) word.
;	RCX holds the number of bits to shift right, RBX holds the 64 bit complement for left shift.
;

ShiftOrR		MACRO			lReg, rReg
				SHLX			RDX, lReg, RBX					; shift 'bottom' bits to top
				SHRX			rReg, rReg, RCX					; shift target bits right (leaving zero filled bits at top)
				OR				rReg, RDX						; OR in new 'top' bits
				ENDM
; Macro for repetitive ops. Reduces chance of typo, easier to maintain, but not used anywhere else
				ShiftOrR		R15, RDI						; RDI is target to shift, but need bits from R15 to fill in high bits
				ShiftOrR		R14, R15						; now R15 is target, but need bits from R14
				ShiftOrR		R13, R14						; and on ...
				ShiftOrR		R12, R13
				ShiftOrR		R11, R12
				ShiftOrR		R10, R11
				ShiftOrR		R9, R10				
				SHRX			R9, R9, RCX						; no bits to OR in on the index 0 (high order) word, just shift it.
@@nobits:
				; with the bits shifted within the words, if the desired shift is more than 64 bits, word shifts are required
				; verify Nr of word shift is zero to seven, use it as index into jump table; jump to appropriate shift
				SHR				R8W, 6							; divide bit shift count by 64 to get Nr words to shift
				AND				R8, 7							; mask out anything above seven (shouldnt happen, but . . . jump table, be sure)
				SHL				R8W, 3							; multiply by 8 to get offset into jump table
				LEA				RAX, jtbl						; base address of jump table
				ADD				R8, RAX							; add to offset
				XOR				RAX, RAX						; clear rax for use in zeroing words shifted "in"
				POP				RBX
				POP				RCX								; restore RBX, RCX
				JMP				Q_PTR [ R8 ]
jtbl:
				QWORD			S0, S1, S2, S3, S4, S5, S6, S7
S0:				; no word shift, just bits, so store words in destination in the same order as they are
				MOV				Q_PTR [ RCX ] [ 0 * 8 ], R9
				MOV				Q_PTR [ RCX ] [ 1 * 8 ], R10
				MOV				Q_PTR [ RCX ] [ 2 * 8 ], R11
				MOV				Q_PTR [ RCX ] [ 3 * 8 ], R12
				MOV				Q_PTR [ RCX ] [ 4 * 8 ], R13
				MOV				Q_PTR [ RCX ] [ 5 * 8 ], R14
				MOV				Q_PTR [ RCX ] [ 6 * 8 ], R15
				MOV				Q_PTR [ RCX ] [ 7 * 8 ], RDI	
				JMP				@@R
S1:
				MOV				Q_PTR [ RCX ] [ 0 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 1 * 8 ], R9
				MOV				Q_PTR [ RCX ] [ 2 * 8 ], R10
				MOV				Q_PTR [ RCX ] [ 3 * 8 ], R11
				MOV				Q_PTR [ RCX ] [ 4 * 8 ], R12
				MOV				Q_PTR [ RCX ] [ 5 * 8 ], R13
				MOV				Q_PTR [ RCX ] [ 6 * 8 ], R14
				MOV				Q_PTR [ RCX ] [ 7 * 8 ], R15	
				JMP				@@R
S2:
				MOV				Q_PTR [ RCX ] [ 0 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 1 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 2 * 8 ], R9
				MOV				Q_PTR [ RCX ] [ 3 * 8 ], R10
				MOV				Q_PTR [ RCX ] [ 4 * 8 ], R11
				MOV				Q_PTR [ RCX ] [ 5 * 8 ], R12
				MOV				Q_PTR [ RCX ] [ 6 * 8 ], R13
				MOV				Q_PTR [ RCX ] [ 7 * 8 ], R14	
				JMP				@@R

S3:				MOV				Q_PTR [ RCX ] [ 0 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 1 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 2 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 3 * 8 ], R9
				MOV				Q_PTR [ RCX ] [ 4 * 8 ], R10
				MOV				Q_PTR [ RCX ] [ 5 * 8 ], R11
				MOV				Q_PTR [ RCX ] [ 6 * 8 ], R12
				MOV				Q_PTR [ RCX ] [ 7 * 8 ], R13	
				JMP				@@R

S4:				MOV				Q_PTR [ RCX ] [ 0 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 1 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 2 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 3 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 4 * 8 ], R9
				MOV				Q_PTR [ RCX ] [ 5 * 8 ], R10
				MOV				Q_PTR [ RCX ] [ 6 * 8 ], R11
				MOV				Q_PTR [ RCX ] [ 7 * 8 ], R12			
				JMP				@@R

S5:				MOV				Q_PTR [ RCX ] [ 0 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 1 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 2 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 3 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 4 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 5 * 8 ], R9
				MOV				Q_PTR [ RCX ] [ 6 * 8 ], R10
				MOV				Q_PTR [ RCX ] [ 7 * 8 ], R11	
				JMP				@@R

S6:				MOV				Q_PTR [ RCX ] [ 0 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 1 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 2 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 3 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 4 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 5 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 6 * 8 ], R9
				MOV				Q_PTR [ RCX ] [ 7 * 8 ], R10	
				JMP				@@R

S7:				MOV				Q_PTR [ RCX ] [ 0 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 1 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 2 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 3 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 4 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 5 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 6 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 7 * 8 ], R9		
@@R:
;	restore non-volatile regs to as-called condition
				POP				RDI
				POP				R15
				POP				R14
				POP				R13
				POP				R12
				RET
	ENDIF	
				Leaf_End		shr_u, ui512


;--------------------------------------------------------------------------------------------------------------------------------------------------------------
;			shl_u		-	shift supplied source 512bit (8 QWORDS) left, put in destination
;			Prototype:		void shl_u( u64* destination, u64* source, u16 bits_to_shift);
;			destination	-	Address of 64 byte aligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			source		-	Address of 64 byte aligned array of 8 64-bit words (QWORDS) 512 bits (in RDX)
;			bits		-	Number of bits to shift. Will fill with zeros, truncate those shifted out (in R8W)
;			returns		-	nothing (0)

				Leaf_Entry		shl_u, ui512
				CheckAlign		RCX								; (OUT) destination of shifted 8 QWORDs
				CheckAlign		RDX								; (IN)	source of 8 QWORDS

				CMP				R8W, 512						; handle edge case, shift 512 or more bits
				JL				@F
				Zero512			RCX								; zero destination
				RET
@@:
				AND				R8, 511							; mask out high bits above shift count, test for 0
				JNE				@F								; handle edge case, shift zero bits
				CMP				RCX, RDX
				JE				@@r
				Copy512			RCX, RDX						; no shift, just copy (destination, source already in regs)
@@r:
				RET
@@:

	IF __UseZ	
				VMOVDQA64		ZMM31, ZM_PTR [ RDX ]			; load the 8 qwords into zmm reg (note: word order)
				LEA				RAX, [ R8 ]
				AND				AX, 03fh
				JZ				@F								; must be multiple of 64 bits to shift, no bits, just words to shift
;			Do the shift of bits within the 64 bit words
				VPBROADCASTQ	ZMM29, RAX						; Nr bits to shift left
				VPXORQ			ZMM28, ZMM28, ZMM28				; 
				VALIGNQ			ZMM30, ZMM28, ZMM31, 1			; shift copy of words right one word (to get low order bits aligned for shift)
				VPSHLDVQ		ZMM31, ZMM30, ZMM29				; shift, concatenating low bits of next word with each word to shift in
@@:
; with the bits shifted within the words, if the desired shift is more than 64 bits, word shifts are required
; verify Nr of word shift is zero to seven, use it as index into jump table; jump to appropriate shift
				SHR				R8W, 6							; divide Nr bits to shift by 8, giving index to jump table
				LEA				RAX, @jt						; address of jump table
				JMP				Q_PTR [ RAX ] [ R8 * 8 ]		; jump to routine that shifts the appropriate Nr words
@jt:
				QWORD			@@E, @@1, @@2, @@3, @@4, @@5, @@6, @@7
;			Do the shifts of multiples of 64 bits (words)
@@1:			VALIGNQ			ZMM31, ZMM28, ZMM31, 1
@@E:			VMOVDQA64		ZM_PTR [ RCX ], ZMM31
				RET

@@2:			VALIGNQ			ZMM31, ZMM28, ZMM31, 2
				VMOVDQA64		ZM_PTR [ RCX ], ZMM31
				RET

@@3:			VALIGNQ			ZMM31, ZMM28, ZMM31, 3
				VMOVDQA64		ZM_PTR [ RCX ], ZMM31
				RET

@@4:			VALIGNQ			ZMM31, ZMM28, ZMM31, 4
				VMOVDQA64		ZM_PTR [ RCX ], ZMM31
				RET

@@5:			VALIGNQ			ZMM31, ZMM28, ZMM31, 5
				VMOVDQA64		ZM_PTR [ RCX ], ZMM31
				RET

@@6:			VALIGNQ			ZMM31, ZMM28, ZMM31, 6
				VMOVDQA64		ZM_PTR [ RCX ], ZMM31
				RET

@@7:			VALIGNQ			ZMM31, ZMM28, ZMM31, 7
				VMOVDQA64		ZM_PTR [ RCX ], ZMM31
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
				MOV				R9, Q_PTR [ RDX ] [ 0 * 8 ]
				MOV				R10, Q_PTR [ RDX ] [ 1 * 8 ]
				MOV				R11, Q_PTR [ RDX ] [ 2 * 8 ]
				MOV				R12, Q_PTR [ RDX ] [ 3 * 8 ]
				MOV				R13, Q_PTR [ RDX ] [ 4 * 8 ]
				MOV				R14, Q_PTR [ RDX ] [ 5 * 8 ]
				MOV				R15, Q_PTR [ RDX ] [ 6 * 8 ]
				MOV				RDI, Q_PTR [ RDX ] [ 7 * 8 ]
;	determine if / how many bits to shift
				LEA 			RCX, [ R8 ]
				AND				CX, 03fh
				JZ				@@nobits
				LEA				AX, [ 64 ]
				SUB				AX, CX
				MOV				CL, AL							; CL right shift Nr
				XCHG			CL, CH
				MOV				CL, R8B							; CH left shift Nr
				AND				CL, 03fh
				XCHG			CL, CH
;
;	Each word is shifted right, and the bits falling out are ORd into the next word.
;	CL holds the number of bits to shift right, CH holds the complement for left shift.
;	The CL register is used for the bit shift number, it is "XCHG" swapped with CH for the left or right shift
;
				MOV				RDX, R10						; Get the first word (of 0 to 7)
				SHR				RDX, CL							; shift it right by 64 - bits to shift, putting first bits at low end of register
				XCHG			CH, CL							; switch CL from bits to shift right, to bits to shift left
				SHL				R9, CL							; Shift the zero (of 0 to 7) word left, truncating "top" bits
				XCHG			CH, CL							; restore CL to the right shift number
				OR				R9, RDX							; "OR" in the low bits from the 6th word into the shifted seventh word
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
				LEA				RAX, @@jtbl
				ADD				R8, RAX
				XOR				RAX, RAX						; clear rax for use as zeroing words shifted "in"
				POP				RCX								; restore RCX, destination address
				JMP				Q_PTR [ R8 ]
@@jtbl:
				QWORD			@@0, @@1, @@2, @@3, @@4, @@5, @@6, @@7
; no word shift, just bits, so store words in destination in the same order as they are
@@0:			
				MOV				Q_PTR [ RCX ] [ 0 * 8 ], R9
				MOV				Q_PTR [ RCX ] [ 1 * 8 ], R10
				MOV				Q_PTR [ RCX ] [ 2 * 8 ], R11
				MOV				Q_PTR [ RCX ] [ 3 * 8 ], R12
				MOV				Q_PTR [ RCX ] [ 4 * 8 ], R13
				MOV				Q_PTR [ RCX ] [ 5 * 8 ], R14
				MOV				Q_PTR [ RCX ] [ 6 * 8 ], R15
				MOV				Q_PTR [ RCX ] [ 7 * 8 ], RDI	
				JMP				@@R
; one word shift, shifting one word (64+ bits) so store words in destination shifted left one, fill with zero
@@1:			
				MOV				Q_PTR [ RCX ] [ 0 * 8 ], R10
				MOV				Q_PTR [ RCX ] [ 1 * 8 ], R11
				MOV				Q_PTR [ RCX ] [ 2 * 8 ], R12
				MOV				Q_PTR [ RCX ] [ 3 * 8 ], R13
				MOV				Q_PTR [ RCX ] [ 4 * 8 ], R14
				MOV				Q_PTR [ RCX ] [ 5 * 8 ], R15
				MOV				Q_PTR [ RCX ] [ 6 * 8 ], RDI
				MOV				Q_PTR [ RCX ] [ 7 * 8 ], RAX	
				JMP				@@R
; two word shift
@@2:			
				MOV				Q_PTR [ RCX ] [ 0 * 8], R11
				MOV				Q_PTR [ RCX ] [ 1 * 8], R12
				MOV				Q_PTR [ RCX ] [ 2 * 8], R13
				MOV				Q_PTR [ RCX ] [ 3 * 8], R14
				MOV				Q_PTR [ RCX ] [ 4 * 8], R15
				MOV				Q_PTR [ RCX ] [ 5 * 8], RDI
				MOV				Q_PTR [ RCX ] [ 6 * 8], RAX
				MOV				Q_PTR [ RCX ] [ 7 * 8], RAX	
				JMP				@@R
; three word shift
@@3:			
				MOV				Q_PTR [ RCX ] [ 0 * 8 ], R12
				MOV				Q_PTR [ RCX ] [ 1 * 8 ], R13
				MOV				Q_PTR [ RCX ] [ 2 * 8 ], R14
				MOV				Q_PTR [ RCX ] [ 3 * 8 ], R15
				MOV				Q_PTR [ RCX ] [ 4 * 8 ], RDI
				MOV				Q_PTR [ RCX ] [ 5 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 6 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 7 * 8 ], RAX	
				JMP				@@R
; four word shift
@@4:			
				MOV				Q_PTR [ RCX ] [ 0 * 8 ], R13
				MOV				Q_PTR [ RCX ] [ 1 * 8 ], R14
				MOV				Q_PTR [ RCX ] [ 2 * 8 ], R15
				MOV				Q_PTR [ RCX ] [ 3 * 8 ], RDI
				MOV				Q_PTR [ RCX ] [ 4 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 5 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 6 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 7 * 8 ], RAX	
				JMP				@@R
; five word shift
@@5:			
				MOV				Q_PTR [ RCX ] [ 0 * 8 ], R14
				MOV				Q_PTR [ RCX ] [ 1 * 8 ], R15
				MOV				Q_PTR [ RCX ] [ 2 * 8 ], RDI
				MOV				Q_PTR [ RCX ] [ 3 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 4 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 5 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 6 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 7 * 8 ], RAX	
				JMP				@@R
; six word shift
@@6:			
				MOV				Q_PTR [ RCX ] [ 0 * 8], R15
				MOV				Q_PTR [ RCX ] [ 1 * 8], RDI
				MOV				Q_PTR [ RCX ] [ 2 * 8], RAX
				MOV				Q_PTR [ RCX ] [ 3 * 8], RAX
				MOV				Q_PTR [ RCX ] [ 4 * 8], RAX
				MOV				Q_PTR [ RCX ] [ 5 * 8], RAX
				MOV				Q_PTR [ RCX ] [ 6 * 8], RAX
				MOV				Q_PTR [ RCX ] [ 7 * 8], RAX	
				JMP				@@R
; seven word shift
@@7:			
				MOV				Q_PTR [ RCX ] [ 0 * 8 ], RDI
				MOV				Q_PTR [ RCX ] [ 1 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 2 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 3 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 4 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 5 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 6 * 8 ], RAX
				MOV				Q_PTR [ RCX ] [ 7 * 8 ], RAX
;	restore non-volatile regs to as-called condition
@@R:		
				POP				RDI
				POP				R15
				POP				R14
				POP				R13
				POP				R12
@@ret:
				RET

	ENDIF
				Leaf_End		shl_u, ui512


;--------------------------------------------------------------------------------------------------------------------------------------------------------------
;			and_u		-	logical 'AND' bits in lh_op, rh_op, put result in destination
;			Prototype:		void and_u( u64* destination, u64* lh_op, u64* rh_op);
;			destination	-	Address of 64 byte aligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			lh_op		-	Address of 64 byte aligned array of 8 64-bit words (QWORDS) 512 bits (in RDX)
;			rh_op		-	Address of 64 byte aligned array of 8 64-bit words (QWORDS) 512 bits (in R8)
;			returns		-	nothing (0)
				Leaf_Entry		and_u, ui512
				CheckAlign		RCX
				CheckAlign		RDX
				CheckAlign		R8

	IF __UseZ	
				VMOVDQA64		ZMM31, ZM_PTR [ RDX ]			; load lh_op	
				VPANDQ			ZMM31, ZMM31, ZM_PTR [ R8 ]		; 'AND' with rh_op
				VMOVDQA64		ZM_PTR [ RCX ], ZMM31			; store at destination address

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
				FOR				idx, < 0, 1, 2, 3, 4, 5, 6, 7 >
				MOV				RAX, Q_PTR [ RDX ] [ idx * 8 ]
				AND				RAX, Q_PTR [ R8 ] [ idx * 8 ]
				MOV				Q_PTR [ RCX ] [ idx * 8 ], RAX
				ENDM

	ENDIF
				RET		
				Leaf_End		and_u, ui512

;--------------------------------------------------------------------------------------------------------------------------------------------------------------
;			or_u		-	logical 'OR' bits in lh_op, rh_op, put result in destination
;			Prototype:		void or_u( u64* destination, u64* lh_op, u64* rh_op);
;			destination	-	Address of 64 byte aligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			lh_op		-	Address of 64 byte aligned array of 8 64-bit words (QWORDS) 512 bits (in RDX)
;			rh_op		-	Address of 64 byte aligned array of 8 64-bit words (QWORDS) 512 bits (in R8)
;			returns		-	nothing (0)

				Leaf_Entry		or_u, ui512
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
				FOR				idx, < 0, 1, 2, 3, 4, 5, 6, 7 >
				MOV				RAX, Q_PTR [ RDX ] [ idx * 8 ]
				OR				RAX,  Q_PTR [ R8 ] [ idx * 8 ]
				MOV				Q_PTR [ RCX ] [ idx * 8 ], RAX
				ENDM

	ENDIF
				RET 
				Leaf_End		or_u, ui512

;--------------------------------------------------------------------------------------------------------------------------------------------------------------
;			xor_u		-	logical 'XOR' bits in lh_op, rh_op, put result in destination
;			Prototype:		void or_u( u64* destination, u64* lh_op, u64* rh_op);
;			destination	-	Address of 64 byte aligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			lh_op		-	Address of 64 byte aligned array of 8 64-bit words (QWORDS) 512 bits (in RDX)
;			rh_op		-	Address of 64 byte aligned array of 8 64-bit words (QWORDS) 512 bits (in R8)
;			returns		-	nothing (0)

				Leaf_Entry		xor_u, ui512
				CheckAlign		RCX
				CheckAlign		RDX
				CheckAlign		R8

	IF __UseZ	
				VMOVDQA64		ZMM31, ZM_PTR [ RDX ]			
				VPXORQ			ZMM31, ZMM31, ZM_PTR [ R8 ]
				VMOVDQA64		ZM_PTR [ RCX ], ZMM31

	ELSEIF __UseY
				VMOVDQA64		YMM4, YM_PTR [ RDX + 0 * 8 ]
				VPXORQ			YMM5, YMM4, YM_PTR [ R8 + 0 * 8 ]
				VMOVDQA64		YM_PTR [ RCX + 0 * 8 ], YMM5
				VMOVDQA64		YMM2, YM_PTR [ RDX + 4 * 8 ]
				VPXORQ			YMM3, YMM2, YM_PTR [ R8 + 4 * 8]
				VMOVDQA64		YM_PTR [ RCX + 4 * 8 ], YMM3

	ELSEIF __UseX
				MOVDQA			XMM4, XM_PTR [ RDX + 0 * 8 ]
				PXOR			XMM4, XM_PTR [ R8 + 0 * 8]
				MOVDQA			XM_PTR [ RCX + 0 * 8 ], XMM4
				MOVDQA			XMM5, XM_PTR [ RDX + 2 * 8 ]
				PXOR			XMM5, XM_PTR [ R8 + 2 * 8]
				MOVDQA			XM_PTR [ RCX + 2 * 8 ], XMM5
				MOVDQA			XMM4, XM_PTR [ RDX + 4 * 8 ]
				PXOR			XMM4, XM_PTR [ R8 + 4 * 8]
				MOVDQA			XM_PTR [ RCX + 4 * 8 ], XMM4
				MOVDQA			XMM5, XM_PTR [ RDX + 6 * 8 ]
				PXOR			XMM5, XM_PTR [ R8 + 6 * 8]
				MOVDQA			XM_PTR [ RCX + 6 * 8 ], XMM5

	ELSE
				FOR				idx, < 0, 1, 2, 3, 4, 5, 6, 7 >
				MOV				RAX, Q_PTR [ RDX ] [ idx * 8 ]
				XOR				RAX,  Q_PTR [ R8 ] [ idx * 8 ]
				MOV				Q_PTR [ RCX ] [ idx * 8 ], RAX
				ENDM

	ENDIF
				RET 
				Leaf_End		xor_u, ui512

;--------------------------------------------------------------------------------------------------------------------------------------------------------------
;			not_u		-	logical 'NOT' bits in source, put result in destination
;			Prototype:		void not_u( u64* destination, u64* source);
;			destination	-	Address of 64 byte aligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			source		-	Address of 64 byte aligned array of 8 64-bit words (QWORDS) 512 bits (in RDX)
;			returns		-	nothing (0)

				Leaf_Entry		not_u, ui512
				CheckAlign		RCX
				CheckAlign		RDX

	IF __UseZ	
				VMOVDQA64		ZMM31, ZM_PTR [RDX]			
				VPANDNQ			ZMM31, ZMM31, qOnes				; qOnes (declared in the data section of this module) is 8 QWORDS, binary all ones
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
				FOR				idx, < 0, 1, 2, 3, 4, 5, 6, 7 >
				MOV				RAX, Q_PTR [ RDX ] [ idx * 8 ]
				NOT				RAX
				MOV				Q_PTR [ RCX ] [ idx * 8 ], RAX
				ENDM

	ENDIF
				RET	
				Leaf_End		not_u, ui512

;--------------------------------------------------------------------------------------------------------------------------------------------------------------
;			msb_u		-	find most significant bit in supplied source 512bit (8 QWORDS)
;			Prototype:		s16 msb_u( u64* source );
;			source		-	Address of 64 byte aligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			returns		-	-1 if no most significant bit, bit number otherwise, bits numbered 0 to 511 inclusive
;			Note:	a returned zero means the significant bit is bit0 of the eighth word of the 512bit source parameter; (the right most bit)
;					a returned 511 means bit63 of the first word (the left most bit)

				Leaf_Entry		msb_u, ui512
				CheckAlign		RCX								; (IN) source to scan 

	IF __UseZ
				VMOVDQA64		ZMM31, ZM_PTR [RCX]				; Load source 
				VPTESTMQ		k1, ZMM31, ZMM31				; find non-zero words (if any)
				KMOVB			EAX, k1
				TZCNT			ECX, EAX						; determine index of word from first non-zero bit in mask
				JNC				@F
				LEA				EAX, [ retcode_neg_one ]		; exit with -1 if all eight qwords are zero (no significant bit)
				RET
@@:
				LEA				EAX, [ 7 ]						; numbering of words in Z regs (and hence in k1 mask) is reverse in significance order
				SUB				EAX, ECX						; so 7 minus leading k bit index becomes index to our ui512 bit qword
				SHL				EAX, 6							; convert index to offset
				VPCOMPRESSQ		ZMM0 {k1}{z}, ZMM31				; compress it into first word of ZMM0, which is also XMM0
				VMOVQ			RCX, XMM0						; extract the non-zero word (k1 still has index to it)
				LZCNT			RCX, RCX						; get the index of the non-zero bit within the word
				ADD				EAX, 63							; LZCNT counts leading non-zero bits. Subtract from 63 to get our bit index
				SUB				EAX, ECX						; Word index * 64 + bit index becomes bit index to first non-zero bit (0 to 511, where )
				RET

	ELSE
				LEA				R10, [ -1 ]						; Initialize loop counter (and index)
@@NextWord:
				INC				R10D
				CMP				R10D, 8
				JNZ				@F								; Loop through values 0 to 7, then exit
				LEA				EAX,  [ retcode_neg_one ]
				RET
@@:
				LZCNT			R11, Q_PTR [ RCX ] [ R10 * 8 ]	; Leading zero count to find significant bit for index 
				JC				@@NextWord						; None found, loop to next word
				LEA				EAX, [ 7 ]
				SUB				EAX, R10D						; calculate seven minus the word index (which word has the msb?)
				SHL				EAX, 6							; times 64 for each word
				LEA				ECX, [ 63 ]
				SUB				ECX, R11D
				ADD				EAX, ECX						; plus the found bit position within the word yields the bit position within the 512 bit source
				RET	

	ENDIF

				Leaf_End		msb_u, ui512

;--------------------------------------------------------------------------------------------------------------------------------------------------------------
;			lsb_u		-	find least significant bit in supplied source 512bit (8 QWORDS)
;			Prototype:		s16 lsb_u( u64* source );
;			source		-	Address of 64 byte aligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			returns		-	-1 if no least significant bit, bit number otherwise, bits numbered 0 to 511 inclusive
;			Note:	a returned zero means the significant bit is bit0 of the eighth word of the 512bit source parameter; (the right most bit)
;					a returned 511 means bit63 of the first word (the left most bit)

				Leaf_Entry		lsb_u, ui512				
				CheckAlign		RCX								; (IN) source to scan

	IF __UseZ
				VMOVDQA64		ZMM31, ZM_PTR [ RCX ]			; Load source 
				VPTESTMQ		k1, ZMM31, ZMM31				; find non-zero words (if any)
				KMOVB			EAX, k1
				LZCNT			ECX, EAX
				JNC				@F
				LEA				EAX, [ retcode_neg_one ]		; exit with -1 if all eight qwords are zero (no significant bit)
				RET
@@:
			;	BSR				ECX, EAX						; determine index of word from last non-zero bit in mask
				LEA				R9D, [ 31 ]
				SUB				R9D, ECX
				LEA				EAX, [ 7 ]
				SUB				EAX, R9D						; convert index to offset
				SHL				RAX, 6
			;	XOR				R9, R9
			;	INC				R9
			;	SHL				R9, CL
			;	KMOVB			k2, R9
				VPCOMPRESSQ		ZMM0 {k1}{z}, ZMM31
				VMOVQ			RCX, XMM0						; extract the non-zero word
				TZCNT				RCX, RCX						; get the index of the non-zero bit within the word
				ADD				EAX, ECX						; Word index * 64 + bit index becomes bit index to first non-zero bit (0 to 511, where )
				RET

	ELSE
				LEA				R10, [ 8 ]		 				; Initialize loop counter (and index)
@@NextWord:
				DEC				R10D
				CMP				R10D, -1
				JNE				@F								; Loop through values 7 to 0, then exit
				LEA				EAX, [ retcode_neg_one ]
				RET
@@:
				TZCNT			RAX, Q_PTR [ RCX ] [ R10 * 8 ]	; Scan indexed word for significant bit
				JC				@@NextWord						; None found, loop to next word
				LEA				R11D, [ 7 ]						;  
				SUB				R11D, R10D						; calculate seven minus the word index (which word has the msb?)
				SHL				R11D, 6							; times 64 for each word
				ADD				EAX, R11D						; plus the BSF found bit position within the word yields the bit position within the 512 bit source
				RET

	ENDIF
				Leaf_End		lsb_u, ui512

END