IFNDEF		legalnotes
legalnotes	EQU		1
.LIST
;
;			ui512aMacros
;
;			File:			compile_time_options.inc
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
;				(currently using VS Community 2022 17.14.10)
;
;				It provides external signatures that allow linkage to C and C++ programs,
;				where a shell/wrapper could encapsulate the methods as part of an object.
;
;				It has assembly time options directing the use of Intel processor extensions: AVX4, AVX2, SIMD, or none:
;				(Z (512), Y (256), or X (128) registers, or regular Q (64bit)).
;				
;				This file contains to options, set them here.
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
ENDIF			; legalnotes

IFNDEF							compile_time_options_INC
compile_time_options_INC		EQU			<1>

;			Configuration choices
__UseZ			EQU				0									; Use AVX4 processor features (512 bit registers and instructions)
__UseY			EQU				0									; Use AVX2 processor features (256 bit registers and instructions)
__UseX			EQU				0									; Use SIMD/SSE processor features (128 bit registers and instructions)
__UseQ			EQU				1									; Do not use extensions, use standard x64 bit registers and instructions
;
__UseBMI2		EQU				1									; Bit manipulation instructions (Haswell and later) ref:https://en.wikipedia.org/wiki/X86_Bit_manipulation_instruction_set
;
__VerifyRegs	EQU				1									; in debug mode, or with unit tests, define routine to verify non-volatile regs 
__CheckAlign	EQU				0									; User is expected to pass arguments aligned on 64 byte boundaries, 
;																	; This setting enforces that with a check. It should not be necessary, but included to help debugging

ENDIF			; compile_time_options_INC