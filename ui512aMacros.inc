;
;			ui512aMacros
;
;			File:			ui512aMacros.inc
;			Author:			John G. Lynch
;			Legal:			Copyright @2024, per MIT License below
;			Date:			May 13, 2024
;

IFNDEF			ui512aMacros_INC
ui512aMacros_INC EQU			<1>

				INCLUDE			legalnotes.inc

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
;

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
LPVOID			TYPEDEF			PTR VOID
;			mask codes (for compares using instructions like VPCMPUQ)
CPEQ			EQU				0
CPLT			EQU				1
CPLE			EQU				2
CPFALSE			EQU				3
CPNE			EQU				4
CPGE			EQU				5
CPGT			EQU				6
CPTRUE			EQU				7

;
; MemConstants <none>
;
;		Define useful constants
;		Note: this must be first in a data segment aligned (64)
;
MemConstants	MACRO
; 
qOnes			QWORD           8 DUP (0ffffffffffffffffh)
zeroQ			DQ				0

;		Return codes commonly used.	
retcode_zero	EQU				0
retcode_one		EQU				1
retcode_neg_one	EQU				-1
;		Sometimes need to get it from memory, not an immediate value. So:
ret_zero		DD				retcode_zero						
ret_one			DD				retcode_one
ret_neg_one		DD				retcode_neg_one

;		Masks commonly used
;		Record form, which can be used as immediate values. Example: OR	R8D, MASK kMask.b8
kMask			RECORD			b8:1, b7:1, b6:1, b5:1, b4:1, b3:1, b2:1, b1:1, b0:1
;		And as memory, for when immediate simply wont do
mskB0			DB				1
mskB1			DB				2
mskB2			DB				4
mskB3			DB				8
mskB4			DB				16
mskB5			DB				32
mskB6			DB				64
mskB7			DB				128
mskAll8			DB				255
				ENDM

;==================================================================================================
;           Notes on x64 calling conventions        specifically "fast call"
; ref: https://learn.microsoft.com/en-us/cpp/build/x64-calling-convention?view=msvc-170
; The callers first four parameters are passed in registers: RCX, RDX, R8, R9 if integer or address
; if floating point XMM0L, XMM1L, XMM2L, XMM3L
; return (if any) is in EAX
;
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
;==================================================================================================

;==================================================================================================
; Selected macros from "macamd64.inc" (c) Microsoft Corporation
;	These macros generate .xdata and .pdata entries in the executable image file.
;	The entries assist in exception and debugging; helping 'unwind' operations.
;	Only a few macros are included, and are reformatted to match coding style:
;	indents and capitalization.
;
; LEAF_ENTRY <Name>, <Section>
;
; Macro Description:
;
;   This macro indicates the beginning of a leaf function.
;
;   A leaf function is one that DOES NOT:
;
;   - manipulate non-volatile registers
;   - manipulate the stack pointer
;   - call other functions
;   - reference an exception handler
;   - contain a prologue
;   - have any unwind data associated with it
;
; Arguments:
;
;   Name - Supplies the name of the function
;
;   Section - Supplies the name of the section within which the function
;             is to appear
;
Leaf_Entry		MACRO			Name, Section
Section			SEGMENT			PARA 'CODE'
				DB				6 DUP (0cch)
				ALIGN			16
				PUBLIC			Name
Name			PROC			FRAME
				.ENDPROLOG
				ENDM

;
; LEAF_END <Name>, <Section>
;
; Macro Description:
;
;   This macro indicates the end of a leaf function.  It must be paired
;   with a LEAF_ENTRY macro that includes matching Name and Section
;   parameters.
;
; Arguments:
;
;   Name - Supplies the name of the function.  Must match that supplied to
;          the corresponding LEAF_ENTRY macro.
;
;   Section - Supplies the name of the section within which the function
;             is to appear.  Must match that supplied to the corresponding
;             LEAF_ENTRY macro.
;
Leaf_End		MACRO			Name, Section
Name			ENDP
Section			ENDS
				ENDM

;===========================================================================================
;          Local macros
;===========================================================================================

;
; CheckAlign <RAddr>
;
;			Test passed variable addresses for 64 byte alignment
;			Note: Better performance if this is off, but for debugging, maybe have it on
;

CheckAlign		MACRO			Raddr
				LOCAL			ok
	IF	__CheckAlign
				TEST			Raddr, 63							; Is specified param aligned 64?
				JZ				ok									; Yes, passes test, continue
				INT				13									; No? fails, break (can substitute other exception handling)
ok:
	ENDIF
				ENDM

;
; VerifyRegs <none>
;
;			If option is on, generate a function, callable by unit test routines, 
;				to save non-volatile registers in passed structure.
;
IF	__VerifyRegs
;--------------------------------------------------------------------------------------------------------------------------------------------------------------
;			EXTERNDEF		reg_verify:PROC	;	void reg_verify ( u64* regstruct)
;			reg_verify		-	copy non-volatile regs into callers struct of nine qwords) intended for unit tests to verify non-volatile regs are not changed
;			Prototype:		-	void reg_verify( uu64* regstruct);
;			regstruct		-	Address of 9 QWORDS in a struct where regs will be copied (in RCX)
; //			reg_verify		-	save non-volatile regs for verification (debug)
; //			Prototype		-	void reg_verify ( u64* reg struct)
EXTERNDEF		reg_verify:PROC	;	void reg_verify ( u64* reg struct)

VerifyRegs		MACRO
				Leaf_Entry		reg_verify, ui512
				MOV				Q_PTR [ RCX ] [ 0 * 8 ], R12
				MOV				Q_PTR [ RCX ] [ 1 * 8 ], R13
				MOV				Q_PTR [ RCX ] [ 2 * 8 ], R14
				MOV				Q_PTR [ RCX ] [ 3 * 8 ], R15
				MOV				Q_PTR [ RCX ] [ 4 * 8 ], RDI
				MOV				Q_PTR [ RCX ] [ 5 * 8 ], RSI
				MOV				Q_PTR [ RCX ] [ 6 * 8 ], RBX
				MOV				Q_PTR [ RCX ] [ 7 * 8 ], RBP
				MOV				Q_PTR [ RCX ] [ 8 * 8 ], RSP
				RET
				Leaf_End		reg_verify, ui512
				ENDM
ENDIF

;
;			Zero a 512 bit destination, conditional assembly based on configuration parameters
;
Zero512			MACRO			dest:REQ
	IF		__UseZ
				CheckAlign		dest
				VPXORQ			ZMM31, ZMM31, ZMM31
				VMOVDQA64		ZM_PTR [ dest ], ZMM31
	ELSEIF	__UseY
				CheckAlign		dest
				VPXORQ			YMM4, YMM4, YMM4
				FOR				idx, < 0, 4 >
				VMOVDQA64		YM_PTR [ dest ] [ idx * 8 ], YMM4
				ENDM
	ELSEIF	__UseX
				CheckAlign		dest
				PXOR			XMM4, XMM4
				FOR				idx, < 0, 2, 4, 6 >
				MOVDQA			XM_PTR [ dest ] [ idx * 8 ], XMM4
				ENDM		
	ELSE
				XOR				RAX, RAX
				FOR				idx,  < 0, 1, 2, 3, 4, 5, 6, 7 >
				MOV				Q_PTR [ dest ] [ idx * 8 ], RAX
				ENDM
	ENDIF
				ENDM

;
;			Zero a 512 bit destination, always use Q_PTR, avoids clock penalty from using SIMD
;
Zero512Q		MACRO			dest:REQ
				XOR				RAX, RAX
				FOR				idx,  < 0, 1, 2, 3, 4, 5, 6, 7 >
				MOV				Q_PTR [ dest ] [ idx * 8 ], RAX
				ENDM

				ENDM

;
;			Copy a 512 bit source to destination, conditional assembly based on configuration parameters
;
Copy512			MACRO			dest:REQ, src:REQ
	IF		__UseZ 
				CheckAlign		dest
				CheckAlign		src
				VMOVDQA64		ZMM31, ZM_PTR [ src ]
				VMOVDQA64		ZM_PTR [ dest ], ZMM31
	ELSEIF	__UseY
				CheckAlign		dest
				CheckAlign		src
				VMOVDQA64		YMM4, YM_PTR [ src + 0 * 8 ]
				VMOVDQA64		YM_PTR [ dest ] [ 0 * 8 ], YMM4	; alternate ymm regs in case pipeline can execute next without waiting for this.
				VMOVDQA64		YMM5, YM_PTR [ src ] [ 4 * 8 ]
				VMOVDQA64		YM_PTR [ dest ] [ 4 * 8 ], YMM5
	ELSEIF	__UseX
				CheckAlign		dest
				CheckAlign		src
				MOVDQA			XMM4, XM_PTR [ src ] [ 0 * 8 ]
				MOVDQA			XM_PTR [ dest ] [ 0 * 8 ], XMM4
				MOVDQA			XMM3, XM_PTR [ src ] [ 2 * 8 ]
				MOVDQA			XM_PTR [ dest ] [ 2 * 8 ], XMM3
				MOVDQA			XMM4, XM_PTR [ src ] [ 4 * 8 ]
				MOVDQA			XM_PTR [ dest ] [ 4 * 8 ], XMM4
				MOVDQA			XMM3, XM_PTR [ src ] [ 6 * 8 ]
				MOVDQA			XM_PTR [ dest ] [ 6 * 8 ], XMM3
	ELSE
				FOR				idx, < 0, 1, 2, 3, 4, 5, 6, 7 >
				MOV				RAX, Q_PTR [ src ] [ idx * 8 ]
				MOV				Q_PTR [ dest ] [ idx * 8 ], RAX
				ENDM
	ENDIF
				ENDM

;
;			Copy a 512 bit source to destination, always use Q_PTR, avoids clock penalty from using SIMD
;
Copy512Q		MACRO			dest:REQ, src:REQ
				FOR				idx, < 0, 1, 2, 3, 4, 5, 6, 7 >
				MOV				RAX, Q_PTR [ src ] [ idx * 8 ]
				MOV				Q_PTR [ dest ] [ idx * 8 ], RAX
				ENDM

				ENDM

ENDIF	; ui512aMacros_INC