#pragma once

#ifndef ui512a_h
#define ui512a_h

//		ui51a.h
// 
//		File:			ui512a.h
//		Author:			John G.Lynch
//		Legal:			Copyright @2024, per MIT License below
//		Date:			May 13, 2024
//

#include "CommonTypeDefs.h"

//	
extern "C"
{
	// Note:  Unless assembled with "__UseQ", all of the u64* arguments passed must be 64 byte aligned (alignas 64); GP fault will occur if not 

	//	Procedures from ui512a.asm module:

	// void zero_u ( u64* destarr ); 
	// fill supplied 512bit (8 QWORDS) with zero
	void zero_u(const u64*);

	// void copy_u ( u64* destarr, u64* srcarr );
	// copy supplied 512bit (8 QWORDS) source to supplied destination
	void copy_u(const u64*, const u64*);

	// void set_uT64 ( u64* destarr, u64 value );
	// set supplied destination 512 bit to supplied u64 value
	void set_uT64(const u64*, const u64);

	// s16 compare_u ( u64* lh_op, u64* rh_op );
	// compare supplied 512bit (8 QWORDS) LH operand to supplied RH operand
	// returns: (0) for equal, -1 for less than, 1 for greater than (logical, unsigned compare)
	s16 compare_u(const u64*, const u64*);

	// s16 compare_uT64 ( u64* lh_op, u64 rh_op );
	// compare supplied 512bit (8 QWORDS) LH operand to supplied 64bit RH operand (value)
	// returns: (0) for equal, -1 for less than, 1 for greater than (logical, unsigned compare)
	s16 compare_uT64(const u64*, const u64);

	// s16 add_u ( u64* sum, u64* addend1, u64* addend2 );
	// add supplied 512bit (8 QWORDS) sources to supplied destination
	// returns: zero for no carry, 1 for carry (overflow)
	s16 add_u(const u64*, const u64*, const u64*);

	// s16 add_uT64 ( u64* sum, u64* addend1, u64 addend2 );
	// add 64bit QWORD (value) to supplied 512bit (8 QWORDS), place in supplied destination
	// returns: zero for no carry, 1 for carry (overflow)
	s16 add_uT64(const u64*, const u64*, const u64);

	// s16 sub_u ( u64* difference, u64* left operand, u64* right operand );
	// subtract supplied 512bit (8 QWORDS) RH OP from LH OP giving difference in destination
	// returns: zero for no borrow, 1 for borrow (underflow)
	s16 sub_u(const u64*, const u64*, const u64*);

	// s16 sub_uT64( u64* difference, u64* left operand, u64 right operand );
	// subtract supplied 64 bit right hand (64 bit value) op from left hand (512 bit) giving difference
	// returns: zero for no borrow, 1 for borrow (underflow)
	s16 sub_uT64(const u64*, const u64*, const u64);

	// void reg_verify(u64* regs);
	// reg_verify - copy non-volatile regs into callers struct of nine qwords; intended for unit tests to verify non-volatile regs are not changed
	void reg_verify(const u64*);

};

#endif