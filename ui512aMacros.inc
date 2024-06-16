.nolist
;
;			ui512aMacros
;
;			File:			ui512aMacros.inc
;			Author:			John G. Lynch
;			Legal:			Copyright @2024, per MIT License below
;			Date:			May 13, 2024
;
;			Notes:
;				ui512 is a small project to provide basic operations for a variable type of unsigned 512 bit integer.
;				The basic operations: zero, copy, compare, add, subtract. Other optional modules provide bit ops and multiply / divide.
;				It is written in assembly language, using the MASM (ml64) assembler provided as an option within Visual Studio (currently using VS Community 2022 17.9.6)
;				It provides external signatures that allow linkage to C and C++ programs, where a shell/wrapper could encapsulate the methods as part of an object.
;				It has assembly time options directing the use of Intel processor extensions: AVX4, AVX2, SIMD, or none: (Z (512), Y (256), or X (128) registers, or regular Q (64bit))
;				If processor extensions are used, the caller must align the variables declared and passed on the appropriate byte boundary (e.g. alignas 64 for 512)
;				This module is very light-weight (less than 1K bytes) and relatively fast, but is not intended for all processor types or all environments. 
;				Use for private (hobbyist), or instructional, or as an example for more ambitious projects is all it is meant to be.
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
.list
IFNDEF						ui512aMacros_INC
ui512aMacros_INC EQU		<1>
;           header file equivalent extern declarations
;			EXTERN "C" signatures (from ui512a.asm)

;	// void zero_u ( u64* destarr ); 
;	// fill supplied 512bit (8 QWORDS) with zero
EXTERNDEF	zero_u:PROC

;	// void copy_u ( u64* destarr, u64* srcarr );
;	// copy supplied 512bit (8 QWORDS) source to supplied destination
EXTERNDEF	copy_u:PROC

;	// void set_uT64 ( u64* destarr, u64 value );
;	// set supplied destination 512 bit to supplied u64 value
EXTERNDEF	set_uT64:PROC

;	// int compare_u ( u64* lh_op, u64* rh_op );
;	// compare supplied 512bit (8 QWORDS) LH operand to supplied RH operand
;	// returns: (0) for equal, -1 for less than, 1 for greater than (logical, unsigned compare)
EXTERNDEF	compare_u:PROC

;	// int compare_uT64 ( u64* lh_op, u64 rh_op );
;	// compare supplied 512bit (8 QWORDS) LH operand to supplied 64bit RH operand (value)
;	// returns: (0) for equal, -1 for less than, 1 for greater than (logical, unsigned compare)
EXTERNDEF	compare_uT64:PROC

;	// void add_u ( u64* sum, u64* addend1, u64* addend2 );
;	// add supplied 512bit (8 QWORDS) sources to supplied destination
;	// returns: zero for no carry, 1 for carry (overflow)
EXTERNDEF	add_u:PROC

;	// s32 add_uT64 ( u64* sum, u64* addend1, u64 addend2 );
;	// add 64bit QWORD (value) to supplied 512bit (8 QWORDS), place in supplied destination
;	// returns: zero for no carry, 1 for carry (overflow)
EXTERNDEF	add_uT64:PROC

;	// s32 sub_u ( u64* difference, u64* left operand, u64* right operand );
;	// subtract supplied 512bit (8 QWORDS) RH OP from LH OP giving difference in destination
;	// returns: zero for no borrow, 1 for borrow (underflow)
EXTERNDEF	sub_u:PROC

;	// s32 sub_uT64( u64* difference, u64* left operand, u64 right operand );
;	// subtract supplied 64 bit right hand (64 bit value) op from left hand (512 bit) giving difference
;	// returns: zero for no borrow, 1 for borrow (underflow)
EXTERNDEF	sub_uT64:PROC

;			Configuration choices
__UseZ		EQU				1							; Use AVX4 processor features (512 bit registers and instructions)
__UseY		EQU				0							; Use AVX2 processor features (256 bit registers and instructions)
__UseX		EQU				0							; Use SIMD/SSE processor features (128 bit registers and instructions)
__UseQ		EQU				0							; Do not use extensions, use standard x64 bit registers and instructions

;           Some coding shortcuts
ZM_PTR      EQU             ZMMWORD PTR
YM_PTR      EQU             YMMWORD PTR
XM_PTR      EQU             XMMWORD PTR
Q_PTR       EQU             QWORD PTR
D_PTR       EQU             DWORD PTR
W_PTR       EQU             WORD PTR
B_PTR       EQU             BYTE PTR
m32BCST     EQU				DWORD BCST
m64BCST     EQU				QWORD BCST

;			mask codes (for compares)
CPEQ		EQU				0
CPLT		EQU				1
CPLE		EQU				2
CPNE		EQU				4
CPGE		EQU				5
CPGT		EQU				6
;===============================================
;          Local macros
;===============================================

;==========================================================================================
;           Notes on x64 calling conventions        aka "fast call"
; ref: https://learn.microsoft.com/en-us/cpp/build/x64-calling-convention?view=msvc-170
; The first four parameters are passed in registers: RCX, RDX, R8, R9 if integer or address
; if floating point XMM0L, XMM1L, XMM2L, XMM3L
; return (if any) is in EAX
;===========================================================================================
;
;===========================================================================================
; RAX, RCX, RDX, R8, R9, R10, R11 are considered volatile, and do not need to be saved
; XMM0, YMM0, ZMM0 and  ..1, ..2, ..3, ..4, and ..5 are considered volatile,
;	and do not need to be saved
;  ZMM16 to ZMM31: volatile, also do not need to be zeroed to resume full clock speeds
;
; R12, R13, R14, R15, RDI, RSI, RBX, RBP, RSP are non-volatile and if used, must be restored
; XMM, YMM, and ZMM ..6 thru 15 are non-volatile and if used, must be restored
;
; A "leaf" function is one that does not call and does not change non volatile registers
; leaf functionss therefore do not need frame, prolog or epilog
;
;===========================================================================================

Zero512		MACRO			dest
;
;			Zero a 512 bit destination, conditional assembly based on configuration parameters
;
	IF		__UseZ
			VPXORQ			ZMM31, ZMM31, ZMM31
			VMOVDQA64		ZM_PTR [ dest ], ZMM31
	ELSEIF	__UseY
			VPXORQ			YMM4, YMM4, YMM4
			VMOVDQA64		YM_PTR [ dest ] + [ 0 * 8 ], YMM4
			VMOVDQA64		YM_PTR [ dest ] + [ 4 * 8 ], YMM4
	ELSEIF	__UseX
			PXOR			XMM4, XMM4
			MOVDQA			XM_PTR [ dest ] + [ 0 * 8 ], XMM4
			MOVDQA			XM_PTR [ dest ] + [ 2 * 8 ], XMM4
			MOVDQA			XM_PTR [ dest ] + [ 4 * 8 ], XMM4
			MOVDQA			XM_PTR [ dest ] + [ 6 * 8 ], XMM4			
	ELSE
			XOR				RAX, RAX
			MOV				[ dest ] + [ 0 * 8 ], RAX
			MOV				[ dest ] + [ 1 * 8 ], RAX
			MOV				[ dest ] + [ 2 * 8 ], RAX
			MOV				[ dest ] + [ 3 * 8 ], RAX
			MOV				[ dest ] + [ 4 * 8 ], RAX
			MOV				[ dest ] + [ 5 * 8 ], RAX
			MOV				[ dest ] + [ 6 * 8 ], RAX
			MOV				[ dest ] + [ 7 * 8 ], RAX
	ENDIF
			ENDM

Copy512		MACRO			dest, src
;
;			Copy a 512 bit source to destination, conditional assembly based on configuration parameters
;
	IF		__UseZ
			VMOVDQA64		ZMM31, ZM_PTR [ src ]
			VMOVDQA64		ZM_PTR [ dest ], ZMM31
	ELSEIF	__UseY
			VMOVDQA64		YMM4, YM_PTR [ src ] + [ 0 * 8 ]
			VMOVDQA64		YM_PTR [ dest ] + [ 0 * 8 ], YMM4
			VMOVDQA64		YMM5, YM_PTR [ src ] + [ 4 * 8 ]
			VMOVDQA64		YM_PTR [ dest ] + [ 4 * 8 ], YMM5
	ELSEIF	__UseX
			MOVDQA			XMM4, XM_PTR [ src ] + [ 0 * 8 ]
			MOVDQA			XM_PTR [ dest ] + [ 0 * 8 ], XMM4
			MOVDQA			XMM3, XM_PTR [ src ] + [ 2 * 8 ]
			MOVDQA			XM_PTR [ dest ] + [ 2 * 8 ], XMM3
			MOVDQA			XMM4, XM_PTR [ src ] + [ 4 * 8 ]
			MOVDQA			XM_PTR [ dest ] + [ 4 * 8 ], XMM4
			MOVDQA			XMM3, XM_PTR [ src ] + [ 6 * 8 ]
			MOVDQA			XM_PTR [ dest ] + [ 6 * 8 ], XMM3
	ELSE
			MOV				RAX, [ src ] + [ 0 * 8 ]
			MOV				[ dest ] + [ 0 * 8 ], RAX
			MOV				RAX, [ src ] + [ 1 * 8 ]
			MOV				[ dest ] + [ 1 * 8 ], RAX
			MOV				RAX, [ src ] + [ 2 * 8 ]
			MOV				[ dest ] + [ 2 * 8 ], RAX
			MOV				RAX, [ src ] + [ 3 * 8 ]
			MOV				[ dest ] + [ 3 * 8 ], RAX
			MOV				RAX, [ src ] + [ 4 * 8 ]
			MOV				[ dest ] + [ 4 * 8 ], RAX
			MOV				RAX, [ src ] + [ 5 * 8 ]
			MOV				[ dest ] + [ 5 * 8 ], RAX
			MOV				RAX, [ src ] + [ 6 * 8 ]
			MOV				[ dest ] + [ 6 * 8 ], RAX
			MOV				RAX, [ src ] + [ 7 * 8 ]
			MOV				[ dest ] + [ 7 * 8 ], RAX
	ENDIF
			ENDM

ENDIF