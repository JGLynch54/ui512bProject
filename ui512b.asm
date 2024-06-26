;
;			ui512b
;
;			File:			ui512b.asm
;			Author:			John G. Lynch
;			Legal:			Copyright @2024, per MIT License below
;			Date:			June 11, 2024
;
;			Notes:
;				ui512 is a small project to provide basic operations for a variable type of unsigned 512 bit integer.
;				The basic operations: zero, copy, compare, add, subtract.
;               Other optional modules provide bit ops and multiply / divide.
;				It is written in assembly language, using the MASM (ml64) assembler provided as an option within Visual Studio.
;				(currently using VS Community 2022 17.9.6)
;				It provides external signatures that allow linkage to C and C++ programs,
;				where a shell/wrapper could encapsulate the methods as part of an object.
;				It has assembly time options directing the use of Intel processor extensions: AVX4, AVX2, SIMD, or none:
;				(Z (512), Y (256), or X (128) registers, or regular Q (64bit)).
;				If processor extensions are used, the caller must align the variables declared and passed
;				on the appropriate byte boundary (e.g. alignas 64 for 512)
;				This module is very light-weight (less than 1K bytes) and relatively fast,
;				but is not intended for all processor types or all environments. 
;				Use for private (hobbyist), or instructional,
;				or as an example for more ambitious projects is all it is meant to be.
;
;				ui512b provides basic bit-oriented operations: shift left, shift right, and, or, not,
;               least significant bit and most significant bit.
;
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
			INCLUDE			ui512aMacros.inc
			INCLUDE			ui512bMacros.inc
			OPTION			casemap:none
.CONST

aligned64   SEGMENT         ALIGN (64)
qOnes       QWORD           8 DUP (0ffffffffffffffffh)
aligned64   ENDS

.CODE
            OPTION          PROLOGUE:none
            OPTION          EPILOGUE:none

;			shr_u		-	shift supplied source 512bit (8 QWORDS) right, put in destination
;			Prototype:		void shr_u( u64* destination, u64* source, u32 bits_to_shift)
;			destination	-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			source		-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RDX)
;			bits		-	Number of bits to shift. Will fill with zeros, truncate those shifted out (in R8W)
;			returns		-	nothing (0)
;			Note: unwound loop(s). More instructions, but fewer executed (no loop save, setup, compare loop), faster, fewer regs used

shr_u		PROC			PUBLIC
			CMP				R8W, 0						; handle edge case, shift zero bits
			JNE				notzero
			CMP				RCX, RDX
			JE				shr_u_ret					; destination is the same as the source: no copy needed
			Copy512			RCX, RDX					; no shift, just copy (destination, source already in regs)
			JMP				shr_u_ret
notzero:
			CMP				R8W, 512					; handle edge case, shift 512 or more bits
			JL				lt512
			Zero512			RCX							; zero destination
			JMP				shr_u_ret
lt512:
	IF		__UseZ
			VMOVDQA64		ZMM31, ZM_PTR [ RDX ]		; load the 8 qwords into zmm reg (note: word order)
			MOV				AX, R8W
			AND				AX, 63
			JZ				nobits						; must be multiple of 64 bits to shift, no bits, just words to shift
			VPBROADCASTQ	ZMM29, RAX					; Nr bits to shift right
			VPXORQ			ZMM28, ZMM28, ZMM28			; 
			VALIGNQ			ZMM30, ZMM31, ZMM28, 7		; shift copy of words left one word (to get low order bits aligned for shift)
			VPSHRDVQ		ZMM31, ZMM30, ZMM29			; shift, concatentating low bits of next word with each word to shift in
nobits:
;			Word shifts:
			SHR				R8W, 6
			JZ				store_exit
			CMP				R8W, 1
			JNE				test2ws
			VALIGNQ			ZMM31, ZMM31, ZMM28, 7
			JMP				store_exit
test2ws:
			CMP				R8W, 2
			JNE				test3ws
			VALIGNQ			ZMM31, ZMM31, ZMM28, 6
			JMP				store_exit
test3ws:
			CMP				R8W, 3
			JNE				test4ws
			VALIGNQ			ZMM31, ZMM31, ZMM28, 5
			JMP				store_exit
test4ws:
			CMP				R8W, 4
			JNE				test5ws
			VALIGNQ			ZMM31, ZMM31, ZMM28, 4
			JMP				store_exit
test5ws:
			CMP				R8W, 5
			JNE				test6ws
			VALIGNQ			ZMM31, ZMM31, ZMM28, 3
			JMP				store_exit
test6ws:
			CMP				R8W, 6
			JNE				shift7ws
			VALIGNQ			ZMM31, ZMM31, ZMM28, 2
			JMP				store_exit
shift7ws:
			VALIGNQ			ZMM31, ZMM31, ZMM28, 1
store_exit:
			VMOVDQA64		ZM_PTR [ RCX ], ZMM31
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
;	determine if / how many words to shift
			MOV				AX, 64
			SUB				AX, R8W
			XOR				RCX, RCX
			MOV				CL, AL						; CL left shift Nr
			XCHG			CL, CH
			MOV				CL, R8B						; CH right shift Nr
			XCHG			CL, CH
			;
			MOV				RDX, R15
			SHL				RDX, CL
			XCHG			CH, CL
			SHR				RDI, CL
			XCHG			CH, CL
			OR				RDI, RDX
			;
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
			;
			SHR				R9, CL
			MOV				AX, R8W
			SHR				AX, 6
			CMP				AX, 0						; no word shift, just bits
			POP				RCX
			JNE				test1ws
			MOV				[RCX + 0 * 8], R9
			MOV				[RCX + 1 * 8], R10
			MOV				[RCX + 2 * 8], R11
			MOV				[RCX + 3 * 8], R12
			MOV				[RCX + 4 * 8], R13
			MOV				[RCX + 5 * 8], R14
			MOV				[RCX + 6 * 8], R15
			MOV				[RCX + 7 * 8], RDI	
			JMP				restore_exit
test1ws:	CMP				AX, 1						; one word shift
			JNE				test2ws
			XOR				RAX, RAX
			MOV				[RCX + 0 * 8], RAX
			MOV				[RCX + 1 * 8], R9
			MOV				[RCX + 2 * 8], R10
			MOV				[RCX + 3 * 8], R11
			MOV				[RCX + 4 * 8], R12
			MOV				[RCX + 5 * 8], R13
			MOV				[RCX + 6 * 8], R14
			MOV				[RCX + 7 * 8], R15	
			JMP				restore_exit
test2ws:	CMP				AX, 2						; two word shift
			JNE				test3ws
			XOR				RAX, RAX
			MOV				[RCX + 0 * 8], RAX
			MOV				[RCX + 1 * 8], RAX
			MOV				[RCX + 2 * 8], R9
			MOV				[RCX + 3 * 8], R10
			MOV				[RCX + 4 * 8], R11
			MOV				[RCX + 5 * 8], R12
			MOV				[RCX + 6 * 8], R13
			MOV				[RCX + 7 * 8], R14	
			JMP				restore_exit
test3ws:	CMP				AX, 3						; three word shift
			JNE				test4ws
			MOV				[RCX + 0 * 8], RAX
			MOV				[RCX + 1 * 8], RAX
			MOV				[RCX + 2 * 8], RAX
			MOV				[RCX + 3 * 8], R9
			MOV				[RCX + 4 * 8], R10
			MOV				[RCX + 5 * 8], R11
			MOV				[RCX + 6 * 8], R12
			MOV				[RCX + 7 * 8], R13	
			JMP				restore_exit
test4ws:	CMP				AX, 4						; four word shift
			JNE				test5ws
			MOV				[RCX + 0 * 8], RAX
			MOV				[RCX + 1 * 8], RAX
			MOV				[RCX + 2 * 8], RAX
			MOV				[RCX + 3 * 8], RAX
			MOV				[RCX + 4 * 8], R9
			MOV				[RCX + 5 * 8], R10
			MOV				[RCX + 6 * 8], R11
			MOV				[RCX + 7 * 8], R12	
			JMP				restore_exit
test5ws:	CMP				AX, 5						; five word shift
			JNE				test6ws
			MOV				[RCX + 0 * 8], RAX
			MOV				[RCX + 1 * 8], RAX
			MOV				[RCX + 2 * 8], RAX
			MOV				[RCX + 3 * 8], RAX
			MOV				[RCX + 4 * 8], RAX
			MOV				[RCX + 5 * 8], R9
			MOV				[RCX + 6 * 8], R10
			MOV				[RCX + 7 * 8], R11	
			JMP				restore_exit
test6ws:	CMP				AX, 6						; six word shift
			JNE				test7ws
			MOV				[RCX + 0 * 8], RAX
			MOV				[RCX + 1 * 8], RAX
			MOV				[RCX + 2 * 8], RAX
			MOV				[RCX + 3 * 8], RAX
			MOV				[RCX + 4 * 8], RAX
			MOV				[RCX + 5 * 8], RAX
			MOV				[RCX + 6 * 8], R9
			MOV				[RCX + 7 * 8], R10	
			JMP				restore_exit
test7ws:												; seven word shift
			MOV				[RCX + 0 * 8], RAX
			MOV				[RCX + 1 * 8], RAX
			MOV				[RCX + 2 * 8], RAX
			MOV				[RCX + 3 * 8], RAX
			MOV				[RCX + 4 * 8], RAX
			MOV				[RCX + 5 * 8], RAX
			MOV				[RCX + 6 * 8], RAX
			MOV				[RCX + 7 * 8], R9	
		
restore_exit:
;	restore non-volitile regs to as-called condition
			POP				RDI
			POP				R15
			POP				R14
			POP				R13
			POP				R12
	ENDIF
shr_u_ret:
			RET		
shr_u		ENDP			

;			shl_u		-	shift supplied source 512bit (8 QWORDS) left, put in destination
;			Prototype:		void shl_u( u64* destination, u64* source, u16 bits_to_shift);
;			destination	-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			source		-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RDX)
;			bits		-	Number of bits to shift. Will fill with zeros, truncate those shifted out (in R8W)
;			returns		-	nothing (0)
shl_u		PROC			PUBLIC
			CMP				R8W, 0						; handle edge case, shift zero bits
			JNE				notzero
			CMP				RCX, RDX
			JE				shl_u_ret
			Copy512			RCX, RDX					; no shift, just copy (destination, source already in regs)
			JMP				shl_u_ret
notzero:
			CMP				R8W, 512					; handle edge case, shift 512 or more bits
			JL				not512
			Zero512			RCX							; zero destination
			JMP				shl_u_ret
not512:
;	copy source to destination, offsetting words if Nr to shift / 64 > 0
			PUSH			RCX
			PUSH			R9
			PUSH			R10
			PUSH			R11
			MOV				R11, RCX					; destination address moved/saved, free up C for word shift counter
			XOR				RCX, RCX
			XOR				RAX, RAX
			MOV				AX, R8W				
			SHR				RAX, 6						; divide shift count by 64 giving word shift count (retain orig count in 8)
			CMP				RAX, 0
			JNE				shiftwords
			CMP				R11, RDX
			JE				destsrcsame
shiftwords:
			MOV				RCX, RAX					; word shift counter to RCX
			XOR				RAX, RAX
			CMP				RCX, 7
			JG				wsf1						; > 7? 
			MOV				RAX, [RDX + RCX * 8]		; get offset word
			INC				RCX
wsf1:		MOV				[R11 + 0 * 8], RAX			; move it (or zero) to first 
			XOR				RAX, RAX
			CMP				RCX, 7
			JG				wsf2
			MOV				RAX, [RDX + RCX * 8]
			INC				RCX
wsf2:		MOV				[R11 + 1 * 8], RAX
			XOR				RAX, RAX
			CMP				RCX, 7
			JG				wsf3
			MOV				RAX, [RDX + RCX * 8]
			INC				RCX
wsf3:		MOV				[R11 + 2 * 8], RAX
			XOR				RAX, RAX
			CMP				RCX, 7
			JG				wsf4
			MOV				RAX, [RDX + RCX * 8]
			INC				RCX
wsf4:		MOV				[R11 + 3 * 8], RAX
			XOR				RAX, RAX
			CMP				RCX, 7
			JG				wsf5
			MOV				RAX, [RDX + RCX * 8]
			INC				RCX
wsf5:       MOV				[R11 + 4 * 8], RAX
			XOR				RAX, RAX
			CMP				RCX, 7
			JG				wsf6
			MOV				RAX, [RDX + RCX * 8]
			INC				RCX
wsf6:		MOV				[R11 + 5 * 8], RAX
			XOR				RAX, RAX
			CMP				RCX, 7
			JG				wsf7
			MOV				RAX, [RDX + RCX * 8]
			INC				RCX
wsf7:		MOV				[R11 + 6 * 8], RAX
			XOR				RAX, RAX
			CMP				RCX, 7
			JG				wsf8
			MOV				RAX, [RDX + RCX * 8]
wsf8:		MOV				[R11 + 7 * 8], RAX
destsrcsame:

; RCX: needed for cl shift counts; use RAX for load/store/shift, RDX for shift/save, R9 for counter/index, r10 bits left (exch with rcx for bits right), R11 for destination
			MOV				RCX, 03Fh					; mask for last six bits of shift counter
			AND				CX, R8W						; passed bit count, now in RCX, ECX, CX, and CL how many bits to shift right
			CMP				CX, 0
			JE				nobitstoshift				; 
			MOV				R10, 64
			SUB				R10, RCX					; 64 - bit shift count (bits at high end of word that survive the shift) XCHG r10, RCX to use CL as shift count

			MOV				RAX, [R11 + 7 * 8]
			SHL				Q_PTR [R11 + 7 * 8], CL		; first word shifted

			XCHG			RCX, R10
			SHR				RAX, CL
			XCHG			RCX, R10
			MOV				R9, [R11 + 6 * 8]
			SHL				Q_PTR [R11 + 6 * 8], CL		; second word shifted 
			OR				Q_PTR [R11 + 6 * 8], RAX	; and low bits ORd in
			MOV				RAX, R9
			
			XCHG			RCX, R10
			SHR				RAX, CL
			XCHG			RCX, R10
			MOV				R9, [R11 + 5 * 8]
			SHL				Q_PTR [R11 + 5 * 8], CL		; third word shifted 
			OR				Q_PTR [R11 + 5 * 8], RAX	; and low bits ORd in
			MOV				RAX, R9
			
			XCHG			RCX, R10
			SHR				RAX, CL
			XCHG			RCX, R10
			MOV				R9, [R11 + 4 * 8]
			SHL				Q_PTR [R11 + 4 * 8], CL		; fourth word shifted 
			OR				Q_PTR [R11 + 4 * 8], RAX	; and low bits ORd in
			MOV				RAX, R9
			
			XCHG			RCX, R10
			SHR				RAX, CL
			XCHG			RCX, R10
			MOV				R9, [R11 + 3 * 8]
			SHL				Q_PTR [R11 + 3 * 8], CL		; fifth word shifted 
			OR				Q_PTR [R11 + 3 * 8], RAX	; and low bits ORd in
			MOV				RAX, R9
			
			XCHG			RCX, R10
			SHR				RAX, CL
			XCHG			RCX, R10
			MOV				R9, [R11 + 2 * 8]
			SHL				Q_PTR [R11 + 2 * 8], CL		; sixth word shifted 
			OR				Q_PTR [R11 + 2 * 8], RAX	; and low bits ORd in
			MOV				RAX, R9
			
			XCHG			RCX, R10
			SHR				RAX, CL
			XCHG			RCX, R10
			MOV				R9, [R11 + 1 * 8]
			SHL				Q_PTR [R11 + 1 * 8], CL		; seventh word shifted 
			OR				Q_PTR [R11 + 1 * 8], RAX	; and low bits ORd in	
			MOV				RAX, R9
						
			XCHG			RCX, R10
			SHR				RAX, CL
			XCHG			RCX, R10
			SHL				Q_PTR [R11 + 0 * 8], CL		; eigth word shifted 
			OR				Q_PTR [R11 + 0 * 8], RAX	; and low bits ORd in	
			
nobitstoshift:
			POP				R11							; restore regs to "as-called" values
			POP				R10
			POP				R9
			POP				RCX
shl_u_ret:
			RET	
shl_u		ENDP

;			and_u		-	logical 'AND' bits in lh_op, rh_op, put result in destination
;			Prototype:		void and_u( u64* destination, u64* lh_op, u64* rh_op);
;			destination	-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			lh_op		-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RDX)
;			rh_op		-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in R8)
;			returns		-	nothing (0)
and_u		PROC			PUBLIC 
	IF		__UseZ		
			VMOVDQA64		ZMM31, ZM_PTR [ RDX ]			
			VPANDQ			ZMM31, ZMM31, ZM_PTR [ R8 ]
			VMOVDQA64		ZM_PTR [ RCX ], ZMM31
	ELSEIF	__UseY
			VMOVDQA64		YMM4, YM_PTR [ RDX ] + [ 0 * 8 ]
			VPANDQ			YMM5, YMM4, YM_PTR [ R8 ] + [ 0 * 8 ]
			VMOVDQA64		YM_PTR [ RCX ] + [ 0 * 8 ], YMM5
			VMOVDQA64		YMM4, YM_PTR [ RDX ] + [ 4 * 8 ]
			VPANDQ			YMM5, YMM4, YM_PTR [ R8 ] + [ 4 * 8]
			VMOVDQA64		YM_PTR [ RCX ] + [ 4 * 8 ], YMM5
	ELSEIF	__UseX
			MOVDQA			XMM4, XM_PTR [ RDX ] + [ 0 * 8 ]
			PAND			XMM4, XM_PTR [ R8 ] + [ 0 * 8]
			MOVDQA			XM_PTR [ RCX ] + [ 0 * 8 ], XMM4
			MOVDQA			XMM4, XM_PTR [ RDX ] + [ 2 * 8 ]
			PAND			XMM4, XM_PTR [ R8 ] + [ 2 * 8]
			MOVDQA			XM_PTR [ RCX ] + [ 2 * 8 ], XMM4
			MOVDQA			XMM4, XM_PTR [ RDX ] + [ 4 * 8 ]
			PAND			XMM4, XM_PTR [ R8 ] + [ 4 * 8]
			MOVDQA			XM_PTR [ RCX ] + [ 4 * 8 ], XMM4
			MOVDQA			XMM4, XM_PTR [ RDX ] + [ 6 * 8 ]
			PAND			XMM4, XM_PTR [ R8 ] + [ 6 * 8]
			MOVDQA			XM_PTR [ RCX ] + [ 6 * 8 ], XMM4
	ELSE
			MOV				RAX, [ RCX ] + [ 0 * 8 ]
			AND				RAX, [ RDX ] + [ 0 * 8 ]
			MOV				[ RCX ] + [ 0 * 8 ], RAX
			MOV				RAX, [ RCX ] + [ 1 * 8 ]
			AND				RAX, [ RDX ] + [ 1 * 8 ]
			MOV				[ RCX ] + [ 1 * 8 ], RAX
			MOV				RAX, [ RCX ] + [ 2 * 8 ]
			AND				RAX, [ RDX ] + [ 2 * 8 ]
			MOV				[ RCX ] + [ 2 * 8 ], RAX
			MOV				RAX, [ RCX ] + [ 3 * 8 ]
			AND				RAX, [ RDX ] + [ 3 * 8 ]
			MOV				[ RCX ] + [ 3 * 8 ], RAX
			MOV				RAX, [ RCX ] + [ 4 * 8 ]
			AND				RAX, [ RDX ] + [ 4 * 8 ]
			MOV				[ RCX ] + [ 4 * 8 ], RAX
			MOV				RAX, [ RCX ] + [ 5 * 8 ]
			AND				RAX, [ RDX ] + [ 5 * 8 ]
			MOV				[ RCX ] + [ 5 * 8 ], RAX			
			MOV				RAX, [ RCX ] + [ 6 * 8 ]
			AND				RAX, [ RDX ] + [ 6 * 8 ]
			MOV				[ RCX ] + [ 6 * 8 ], RAX
			MOV				RAX, [ RCX ] + [ 7 * 8 ]
			AND				RAX, [ RDX ] + [ 7 * 8 ]
			MOV				[ RCX ] + [ 7 * 8 ], RAX
	ENDIF
			RET		
and_u		ENDP

;			or_u		-	logical 'OR' bits in lh_op, rh_op, put result in destination
;			Prototype:		void or_u( u64* destination, u64* lh_op, u64* rh_op);
;			destination	-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			lh_op		-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RDX)
;			rh_op		-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in R8)
;			returns		-	nothing (0)
or_u		PROC			PUBLIC
	IF		__UseZ		
			VMOVDQA64		ZMM31, ZM_PTR [ RDX ]			
			VPORQ			ZMM31, ZMM31, ZM_PTR [ R8 ]
			VMOVDQA64		ZM_PTR [ RCX ], ZMM31
	ELSEIF	__UseY
			VMOVDQA64		YMM4, YM_PTR [ RDX ] + [ 0 * 8 ]
			VPORQ			YMM5, YMM4, YM_PTR [ R8 ] + [ 0 * 8 ]
			VMOVDQA64		YM_PTR [ RCX ] + [ 0 * 8 ], YMM5
			VMOVDQA64		YMM4, YM_PTR [ RDX ] + [ 4 * 8 ]
			VPORQ			YMM5, YMM4, YM_PTR [ R8 ] + [ 4 * 8]
			VMOVDQA64		YM_PTR [ RCX ] + [ 4 * 8 ], YMM5
	ELSEIF	__UseX
			MOVDQA			XMM4, XM_PTR [ RDX ] + [ 0 * 8 ]
			POR				XMM4, XM_PTR [ R8 ] + [ 0 * 8]
			MOVDQA			XM_PTR [ RCX ] + [ 0 * 8 ], XMM4
			MOVDQA			XMM4, XM_PTR [ RDX ] + [ 2 * 8 ]
			POR				XMM4, XM_PTR [ R8 ] + [ 2 * 8]
			MOVDQA			XM_PTR [ RCX ] + [ 2 * 8 ], XMM4
			MOVDQA			XMM4, XM_PTR [ RDX ] + [ 4 * 8 ]
			POR				XMM4, XM_PTR [ R8 ] + [ 4 * 8]
			MOVDQA			XM_PTR [ RCX ] + [ 4 * 8 ], XMM4
			MOVDQA			XMM4, XM_PTR [ RDX ] + [ 6 * 8 ]
			POR				XMM4, XM_PTR [ R8 ] + [ 6 * 8]
			MOVDQA			XM_PTR [ RCX ] + [ 6 * 8 ], XMM4
	ELSE
			MOV				RAX, [ RDX ] + [ 0 * 8 ]
			OR				RAX,  [ R8 ] + [ 0 * 8 ]
			MOV				[ RCX ] + [ 0 * 8 ], RAX
			MOV				RAX, [ RDX ] + [ 1 * 8 ]
			OR				RAX, [ R8 ] + [ 1 * 8 ]
			MOV				[ RCX ] + [ 1 * 8 ], RAX
			MOV				RAX, [ RDX ] + [ 2 * 8 ]
			OR				RAX, [ R8 ] + [ 2 * 8 ]
			MOV				[ RCX ] + [ 2 * 8 ], RAX
			MOV				RAX, [ RDX ] + [ 3 * 8 ]
			OR				RAX, [ R8 ] + [ 3 * 8 ]
			MOV				[ RCX ] + [ 3 * 8 ], RAX
			MOV				RAX, [ RDX ] + [ 4 * 8 ]
			OR				RAX, [ R8 ] + [ 4 * 8 ]
			MOV				[ RCX ] + [ 4 * 8 ], RAX
			MOV				RAX, [ RDX ] + [ 5 * 8 ]
			OR				RAX, [ R8 ] + [ 5 * 8 ]
			MOV				[ RCX ] + [ 5 * 8 ], RAX			
			MOV				RAX, [ RDX ] + [ 6 * 8 ]
			OR				RAX, [ R8 ] + [ 6 * 8 ]
			MOV				[ RCX ] + [ 6 * 8 ], RAX
			MOV				RAX, [ RDX ] + [ 7 * 8 ]
			OR				RAX, [ R8 ] + [ 7 * 8 ]
			MOV				[ RCX ] + [ 7 * 8 ], RAX
	ENDIF
			RET 
or_u		ENDP

;			not_u		-	logical 'NOT' bits in source, put result in destination
;			Prototype:		void not_u( u64* destination, u64* source);
;			destination	-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			source		-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RDX)
;			returns		-	nothing (0)
not_u		PROC			PUBLIC
	IF		__UseZ	
			VMOVDQA64		ZMM31, ZM_PTR [RDX]			
			VPANDNQ			ZMM31, ZMM31, qOnes
			VMOVDQA64		ZM_PTR [RCX], ZMM31
	ELSEIF	__UseY
			VMOVDQA64		YMM4, YM_PTR [ RDX ] + [ 0 * 8 ]
			VPANDNQ			YMM5, YMM4, qOnes
			VMOVDQA64		YM_PTR [ RCX ] + [ 0 * 8 ], YMM5
			VMOVDQA64		YMM4, YM_PTR [ RDX ] + [ 4 * 8 ]
			VPANDNQ			YMM5, YMM4, qOnes
			VMOVDQA64		YM_PTR [ RCX ] + [ 4 * 8 ], YMM5
	ELSEIF	__UseX
			MOVDQA			XMM4, XM_PTR [ RDX ] + [ 0 * 8 ]
			PANDN			XMM4, XM_PTR qOnes
			MOVDQA			XM_PTR [ RCX ] + [ 0 * 8 ], XMM4
			MOVDQA			XMM4, XM_PTR [ RDX ] + [ 2 * 8 ]
			PANDN			XMM4, XM_PTR qOnes
			MOVDQA			XM_PTR [ RCX ] + [ 2 * 8 ], XMM4
			MOVDQA			XMM4, XM_PTR [ RDX ] + [ 4 * 8 ]
			PANDN			XMM4, XM_PTR qOnes
			MOVDQA			XM_PTR [ RCX ] + [ 4 * 8 ], XMM4
			MOVDQA			XMM4, XM_PTR [ RDX ] + [ 6 * 8 ]
			PANDN			XMM4, XM_PTR qOnes
			MOVDQA			XM_PTR [ RCX ] + [ 6 * 8 ], XMM4
	ELSE
			MOV				RAX, [ RDX ] + [ 0 * 8 ]
			NOT				RAX
			MOV				[ RCX ] + [ 0 * 8 ], RAX
			MOV				RAX, [ RDX ] + [ 1 * 8 ]
			NOT				RAX
			MOV				[ RCX ] + [ 1 * 8 ], RAX
			MOV				RAX, [ RDX ] + [ 2 * 8 ]
			NOT				RAX
			MOV				[ RCX ] + [ 2 * 8 ], RAX
			MOV				RAX, [ RDX ] + [ 3 * 8 ]
			NOT				RAX
			MOV				[ RCX ] + [ 3 * 8 ], RAX
			MOV				RAX, [ RDX ] + [ 4 * 8 ]
			NOT				RAX
			MOV				[ RCX ] + [ 4 * 8 ], RAX
			MOV				RAX, [ RDX ] + [ 5 * 8 ]
			NOT				RAX
			MOV				[ RCX ] + [ 5 * 8 ], RAX			
			MOV				RAX, [ RDX ] + [ 6 * 8 ]
			NOT				RAX
			MOV				[ RCX ] + [ 6 * 8 ], RAX
			MOV				RAX, [ RDX ] + [ 7 * 8 ]
			NOT				RAX
			MOV				[ RCX ] + [ 7 * 8 ], RAX
	ENDIF
			RET	
not_u		ENDP

;			msb_u		-	find most significant bit in supplied source 512bit (8 QWORDS)
;			Prototype:		s16 msb_u( u64* source );
;			source		-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			returns		-	-1 if no most significant bit, bit number otherwise, bits numbered 0 to 511 inclusive
			OPTION			PROLOGUE:none
			OPTION			EPILOGUE:none
msb_u		PROC			PUBLIC
			PUSH			R9
			PUSH			R10
			XOR				R10, R10
			MOV				R10D, -1
again:
			INC				R10D
			CMP				R10D, 8
			JNZ				chkbits
			MOV				EAX, -1
			JMP				rret
chkbits:
			BSR				RAX, [ RCX ]  + [ R10 * 8 ]
			JZ				again
			MOV				R11D, 7
			SUB				R11D, R10D
			SHL				R11D, 6
			ADD				EAX, R11D
rret:
			POP				R10
			POP				R9
			RET		
msb_u		ENDP

;			lsb_u		-	find least significant bit in supplied source 512bit (8 QWORDS)
;			Prototype:		s16 lsb_u( u64* source );
;			source		-	Address of 64 byte alligned array of 8 64-bit words (QWORDS) 512 bits (in RCX)
;			returns		-	-1 if no least significant bit, bit number otherwise, bits numbered 0 to 511 inclusive
			OPTION			PROLOGUE:none
			OPTION			EPILOGUE:none
lsb_u		PROC			PUBLIC
			PUSH			R9
			PUSH			R10
			MOV				R10, 8
again:
			SUB				R10D, 1
			JNC				chkbits
			MOV				EAX, -1
			JMP				lret
chkbits:
			BSF				RAX, [ RCX ] + [ R10 * 8 ]
			JZ				again
			MOV				R11D, 7
			SUB				R11D, R10D
			SHL				R11D, 6
			ADD				EAX, R11D
lret:
			POP				R10
			POP				R9
			RET
lsb_u		ENDP

			END