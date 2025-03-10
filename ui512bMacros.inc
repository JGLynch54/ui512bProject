.nolist
;
;			ui512bMacros
;
;--------------------------------------------------------------------------------------------------------------------------------------------------------------
;			File:			ui512bMacros.inc
;			Author:			John G. Lynch
;			Legal:			Copyright @2024, per MIT License below
;			Date:			June 11, 2024
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
IFNDEF			ui512bMacros_INC
ui512bMacros_INC EQU		<1>
;           header file equivalent extern declarations
;			EXTERN "C" signatures (from ui512b.asm)

;   // void shr_u ( u64* destination, u64* source, u16 bits_to_shift )
;   // shift supplied source 512bit (8 QWORDS) right, put in destination
EXTERNDEF		shr_u:PROC

;   // void shl_u ( u64* destination, u64* source, u16 bits_to_shift );
;   // shift supplied source 512bit (8 QWORDS) left, put in destination
EXTERNDEF		shl_u:PROC

;   // void and_u ( u64* destination, u64* lh_op, u64* rh_op );
;   // logical 'AND' bits in lh_op, rh_op, put result in destination
EXTERNDEF		and_u:PROC

;   // logical 'OR' bits in lh_op, rh_op, put result in destination
;   // void or_u( u64* destination, u64* lh_op, u64* rh_op);
EXTERNDEF		or_u:PROC

;   // logical 'NOT' bits in source, put result in destination
;	// void not_u( u64* destination, u64* source);
EXTERNDEF		not_u:PROC

;   // find most significant bit in supplied source 512bit (8 QWORDS)
;	// s16 msb_u( u64* );
;   // returns: -1 if no most significant bit, bit number otherwise, bits numbered 0 to 511 inclusive
;	//	Note:	a returned zero means the significant bit is bit0 of the eighth word of the 512bit source parameter; (the right most bit)
;	//			a returned 511 means bit63 of the first word(the left most bit);	//	a returned 511 means bit63 of the first word
EXTERNDEF		msb_u:PROC

;   // find least significant bit in supplied source 512bit (8 QWORDS)
;	// s16 lsb_u( u64* );
;   // returns: -1 if no least significant bit, bit number otherwise, bits numbered 0 to 511 inclusive
;	//	Note:	a returned zero means the significant bit is bit0 of the eighth word of the 512bit source parameter; (the right most bit)
;	//			a returned 511 means bit63 of the first word(the left most bit);	//	a returned 511 means bit63 of the first word
EXTERNDEF		lsb_u:PROC

ENDIF