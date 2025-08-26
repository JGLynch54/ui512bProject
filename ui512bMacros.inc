;
;			ui512bMacros
;
;--------------------------------------------------------------------------------------------------------------------------------------------------------------
;			File:			ui512bMacros.inc
;			Author:			John G. Lynch
;			Legal:			Copyright @2024, per MIT License below
;			Date:			June 11, 2024
;	

IFNDEF			ui512bMacros_INC
ui512bMacros_INC EQU		<1>

				INCLUDE			legalnotes.inc

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

;   // logical 'XOR' bits in lh_op, rh_op, put result in destination
;   // void xor_u( u64* destination, u64* lh_op, u64* rh_op);
EXTERNDEF		xor_u:PROC

;   // logical 'NOT' bits in source, put result in destination
;	// void not_u( u64* destination, u64* source);
EXTERNDEF		not_u:PROC

;   // find most significant bit in supplied source 512bit (8 QWORDS)
;	// s16 msb_u( u64* );
;   // returns: -1 if no most significant bit, bit number otherwise, bits numbered 0 to 511 inclusive
;	//	Note:	a returned zero means the significant bit is bit0 of the eighth word of the 512bit source parameter; (the right most bit).
;	//			a returned 511 means bit63 of the first word; (the left most bit).	
EXTERNDEF		msb_u:PROC

;   // find least significant bit in supplied source 512bit (8 QWORDS)
;	// s16 lsb_u( u64* );
;   // returns: -1 if no least significant bit, bit number otherwise, bits numbered 0 to 511 inclusive
;	//	Note:	a returned zero means the significant bit is bit0 of the eighth word of the 512bit source parameter; (the right most bit).
;	//			a returned 511 means bit63 of the first word; (the left most bit).	
EXTERNDEF		lsb_u:PROC

;==================================================================================================

; Local macros

; Each word is shifted right, and the bits shifted out are ORd into the next (less significant) word.
; RCX holds the number of bits to shift right, RBX holds the 64 bit complement for left shift.
ShiftOrR		MACRO			lReg, rReg
				SHLX			RDX, lReg, RBX					; shift 'bottom' bits to top
				SHRX			rReg, rReg, RCX					; shift target bits right (leaving zero filled bits at top)
				OR				rReg, RDX						; OR in new 'top' bits
				ENDM

; Each word is shifted left, and the bits shifted out are ORd into the next (more significant) word.
; RCX holds the number of bits to shift left, RBX holds the 64 bit complement for right shift.
ShiftOrL		MACRO			lReg, rReg
				SHRX			RDX, lReg, RBX					; shift 'top' bits to bottom
				SHLX			rReg, rReg, RCX					; shift target bits left (leaving zero filled bits at bottom)
				OR				rReg, RDX						; OR in new 'bottom' bits
				ENDM

ENDIF			; ui512bMacros_INC