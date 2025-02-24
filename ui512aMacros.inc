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
;
;				ui512a provides basic operations: zero, copy, compare, add, subtract.
;				ui512b provides basic bit-oriented operations: shift left, shift right, and, or, not, least significant bit and most significant bit.
;               ui512md provides multiply and divide.
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
;				on the appropriate byte boundary (e.g. alignas 64 for 512)
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
.list
IFNDEF			ui512aMacros_INC
ui512aMacros_INC EQU		<1>

;           header file equivalent extern declarations
;			EXTERN "C" signatures (from ui512a.asm)

;	// void zero_u ( u64* destarr ); 
;	// fill supplied 512bit (8 QWORDS) with zero
EXTERNDEF		zero_u:PROC

;	// void copy_u ( u64* destarr, u64* srcarr );
;	// copy supplied 512bit (8 QWORDS) source to supplied destination
EXTERNDEF		copy_u:PROC

;	// void set_uT64 ( u64* destarr, u64 value );
;	// set supplied destination 512 bit to supplied u64 value
EXTERNDEF		set_uT64:PROC

;	// s16 compare_u ( u64* lh_op, u64* rh_op );
;	// compare supplied 512bit (8 QWORDS) LH operand to supplied RH operand
;	// returns: (0) for equal, -1 for less than, 1 for greater than (logical, unsigned compare)
EXTERNDEF		compare_u:PROC

;	// s16 compare_uT64 ( u64* lh_op, u64 rh_op );
;	// compare supplied 512bit (8 QWORDS) LH operand to supplied 64bit RH operand (value)
;	// returns: (0) for equal, -1 for less than, 1 for greater than (logical, unsigned compare)
EXTERNDEF		compare_uT64:PROC

;	// s16 add_u ( u64* sum, u64* addend1, u64* addend2 );
;	// add supplied 512bit (8 QWORDS) sources, place in supplied destination
;	// returns: zero for no carry, 1 for carry (overflow)
EXTERNDEF		add_u:PROC

;	// s16 add_uT64 ( u64* sum, u64* addend1, u64 addend2 );
;	// add 64bit QWORD (value) to supplied 512bit (8 QWORDS), place in supplied destination
;	// returns: zero for no carry, 1 for carry (overflow)
EXTERNDEF		add_uT64:PROC

;	// s16 sub_u ( u64* difference, u64* left operand, u64* right operand );
;	// subtract supplied 512bit (8 QWORDS) RH OP from LH OP giving difference in destination
;	// returns: zero for no borrow, 1 for borrow (underflow)
EXTERNDEF		sub_u:PROC

;	// s16 sub_uT64( u64* difference, u64* left operand, u64 right operand );
;	// subtract supplied 64 bit right hand (64 bit value) op from left hand (512 bit) giving difference
;	// returns: zero for no borrow, 1 for borrow (underflow)
EXTERNDEF		sub_uT64:PROC

;			Configuration choices
__PrefZ			EQU				0									; Load into Z, operate with no memory fetch / store un til done
__PrefQ			EQU				0									; Load data into sequence of regs (requires push/pop save/restore)
;
__UseZ			EQU				1									; Use AVX4 processor features (512 bit registers and instructions)
__UseY			EQU				0									; Use AVX2 processor features (256 bit registers and instructions)
__UseX			EQU				0									; Use SIMD/SSE processor features (128 bit registers and instructions)
__UseQ			EQU				1									; Do not use extensions, use standard x64 bit registers and instructions
;
__CheckAlign	EQU				0									; User is expected to pass arguments aligned on 64 byte boundaries, 
																	; This setting enforces that with a check. It should not be necessary, but included to help debugging

;           Some coding shortcuts
ZM_PTR			EQU				ZMMWORD PTR
YM_PTR			EQU				YMMWORD PTR
XM_PTR			EQU				XMMWORD PTR
Q_PTR			EQU				QWORD PTR
D_PTR			EQU				DWORD PTR
W_PTR			EQU				WORD PTR
B_PTR			EQU				BYTE PTR
m32BCST			EQU				DWORD BCST
m64BCST			EQU				QWORD BCST

;			mask codes (for compares using instructions like VPCMPUQ)
CPEQ			EQU				0
CPLT			EQU				1
CPLE			EQU				2
CPNE			EQU				4
CPGE			EQU				5
CPGT			EQU				6

;			Mask values (for k reg) used to select particulare QWORDS from X, Y, or Z simd regs
MaskBit0		EQU				B_PTR [ 00000001b ]
MaskBit1		EQU				B_PTR [ 00000010b ]
MaskBit2		EQU				B_PTR [ 00000100b ]
MaskBit3		EQU				B_PTR [ 00001000b ]
MaskBit4		EQU				B_PTR [ 00010000b ]
MaskBit5		EQU				B_PTR [ 00100000b ]
MaskBit6		EQU				B_PTR [ 01000000b ]
MaskBit7		EQU				B_PTR [ 10000000b ]
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


;===========================================================================================
;          Local macros
;===========================================================================================

;
;			Test passed variable addresses for 64 byte alignment
;			Note: Better performance if this is off, but for debugging, maybe have it on
;

CheckAlign		MACRO			Raddr
				LOCAL			ok
	IF	__CheckAlign
				TEST			Raddr, 63							; Is specified param aligned 64?
				JZ				ok									; Yes, passes test, continue
				INT				0									; No, fails, break (can substitute other exception handling)
ok:
	ENDIF
				ENDM

MemConstants	MACRO
;		Return codes commonly used.			
ret0			DD				0								
ret1			DD				1
ret_1			DD				-1
;		Masks commonly used
mskAll8			DB				255
mskB0			DB				1
mskB1			DB				2
mskB2			DB				4
mskB3			DB				8
mskB4			DB				16
mskB5			DB				32
mskB6			DB				64
mskB7			DB				128
				ENDM
;
;			Zero a 512 bit destination, conditional assembly based on configuration parameters
;

Zero512			MACRO			dest
				CheckAlign		dest
	IF	__UseZ
				VPXORQ			ZMM31, ZMM31, ZMM31
				VMOVDQA64		ZM_PTR [ dest ], ZMM31
	ELSEIF	__UseY
				VPXORQ			YMM4, YMM4, YMM4
				VMOVDQA64		YM_PTR [ dest + 0 * 8 ], YMM4
				VMOVDQA64		YM_PTR [ dest + 4 * 8 ], YMM4
	ELSEIF	__UseX
				PXOR			XMM4, XMM4
				MOVDQA			XM_PTR [ dest + 0 * 8 ], XMM4
				MOVDQA			XM_PTR [ dest + 2 * 8 ], XMM4
				MOVDQA			XM_PTR [ dest + 4 * 8 ], XMM4
				MOVDQA			XM_PTR [ dest + 6 * 8 ], XMM4			
	ELSE
				XOR				RAX, RAX
				MOV				[ dest + 0 * 8 ], RAX
				MOV				[ dest + 1 * 8 ], RAX
				MOV				[ dest + 2 * 8 ], RAX
				MOV				[ dest + 3 * 8 ], RAX
				MOV				[ dest + 4 * 8 ], RAX
				MOV				[ dest + 5 * 8 ], RAX
				MOV				[ dest + 6 * 8 ], RAX
				MOV				[ dest + 7 * 8 ], RAX
	ENDIF
				ENDM


;
;			Copy a 512 bit source to destination, conditional assembly based on configuration parameters
;

Copy512			MACRO			dest, src
				CheckAlign		dest
				CheckAlign		src
	IF	__UseZ
				VMOVDQA64		ZMM31, ZM_PTR [ src ]
				VMOVDQA64		ZM_PTR [ dest ], ZMM31
	ELSEIF	__UseY
				VMOVDQA64		YMM4, YM_PTR [ src + 0 * 8 ]
				VMOVDQA64		YM_PTR [ dest + 0 * 8 ], YMM4	; alternate ymm regs in case pipeline can execute next without waiting for this.
				VMOVDQA64		YMM5, YM_PTR [ src + 4 * 8 ]
				VMOVDQA64		YM_PTR [ dest + 4 * 8 ], YMM5
	ELSEIF	__UseX
				MOVDQA			XMM4, XM_PTR [ src + 0 * 8 ]
				MOVDQA			XM_PTR [ dest + 0 * 8 ], XMM4
				MOVDQA			XMM3, XM_PTR [ src + 2 * 8 ]
				MOVDQA			XM_PTR [ dest + 2 * 8 ], XMM3
				MOVDQA			XMM4, XM_PTR [ src + 4 * 8 ]
				MOVDQA			XM_PTR [ dest + 4 * 8 ], XMM4
				MOVDQA			XMM3, XM_PTR [ src + 6 * 8 ]
				MOVDQA			XM_PTR [ dest + 6 * 8 ], XMM3
	ELSE
				MOV				RAX, [ src + 0 * 8 ]
				MOV				[ dest + 0 * 8 ], RAX
				MOV				RAX, [ src + 1 * 8 ]
				MOV				[ dest + 1 * 8 ], RAX
				MOV				RAX, [ src + 2 * 8 ]
				MOV				[ dest + 2 * 8 ], RAX
				MOV				RAX, [ src + 3 * 8 ]
				MOV				[ dest + 3 * 8 ], RAX
				MOV				RAX, [ src + 4 * 8 ]
				MOV				[ dest + 4 * 8 ], RAX
				MOV				RAX, [ src + 5 * 8 ]
				MOV				[ dest + 5 * 8 ], RAX
				MOV				RAX, [ src + 6 * 8 ]
				MOV				[ dest + 6 * 8 ], RAX
				MOV				RAX, [ src + 7 * 8 ]
				MOV				[ dest + 7 * 8 ], RAX
	ENDIF
				ENDM

;
;			Get a GP reg QWORD from within a Z register as specified by mask
;			Note: RAX, ZMM0 and k1 are used and not restored
;			Example usage: GetZatIdx R11, ZMM1, MaskBit2 or SetZatIdx ZMM1, R12, [ R9 ]  (where R9 is a bit mask, not an integer index)
;			Note: These are req to reg ops; no memory fetches (other than instructions from pipeline)
;

GetZatMask		MACRO			dest, src, mask
				LEA				RAX,  mask
				KMOVB			k1, RAX
				VPCOMPRESSQ		ZMM0 {k1}{z}, src
				VMOVQ			dest, XMM0
				ENDM

;
;			Set a GP Reg QWORD within a Z register as specified by mask
;			Note: RAX and k1 are used and not restored
;			Example usage: SetZatIdx ZMM1, R8, MaskBit2
;			Note: These are req to reg ops; no memory fetches (other than instructions from pipeline)
;

SetZatMask		MACRO			dest, src, mask
				LEA				RAX, mask
				KMOVB			k1, RAX
				VPBROADCASTQ 	dest {k1}, src
				ENDM
ENDIF