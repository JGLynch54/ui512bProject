#pragma once

#ifndef ui512b_h
#define ui512b_h

//		ui51b.h
// 
//		File:			ui51b.h
//		Author:			John G.Lynch
//		Legal:			Copyright @2024, per MIT License below
//		Date:			June 11, 2024
//

#include "CommonTypeDefs.h"

extern "C"
{
	// Note:  Unless assembled with "__UseQ", all of the u64* arguments passed must be 64 byte aligned (alignas 64); GP fault will occur if not 

	//	Procedures from ui512b.asm module:

	// void shr_u ( u64* destination, u64* source, u32 bits_to_shift );
	// shift supplied source 512bit (8 QWORDS) right, put in destination
	// EXTERNDEF	shr_u : PROC
	void shr_u ( u64*, u64*, u32 );

	// void shl_u ( u64* destination, u64* source, u16 bits_to_shift );
	// shift supplied source 512bit (8 QWORDS) left, put in destination
	// EXTERNDEF	shl_u : PROC
	void shl_u ( u64*, u64*, u16 );

	// void and_u ( u64* destination, u64* lh_op, u64* rh_op );
	// logical 'AND' bits in lh_op, rh_op, put result in destination
	// EXTERNDEF	and_u : PROC
	void and_u ( u64*, u64*, u64* );

	// void or_u ( u64* destination, u64* lh_op, u64* rh_op );
	// logical 'OR' bits in lh_op, rh_op, put result in destination	
	// EXTERNDEF	or_u : PROC
	void or_u ( u64*, u64*, u64* );

	// void not_u ( u64* destination, u64* source );
	// logical 'NOT' bits in source, put result in destination
	// EXTERNDEF	not_u : PROC
	void not_u ( u64*, u64* );

	s16 msb_u ( u64* );
	// find most significant bit in supplied source 512bit (8 QWORDS)
	// returns: -1 if no most significant bit, bit number otherwise, bits numbered 0 to 511 inclusive
	// EXTERNDEF	msb_u : PROC

	s16 lsb_u ( u64* );
	// find least significant bit in supplied source 512bit (8 QWORDS)
	// returns: -1 if no least significant bit, bit number otherwise, bits numbered 0 to 511 inclusive
	// EXTERNDEF	lsb_u : PROC
};

#endif