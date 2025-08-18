#pragma once
#ifndef CommonTypeDefs_h
#define CommonTypeDefs_h

//		CommonTypeDefs
// 
//		File:			CommonTypeDefs.cpp
//		Author:			John G.Lynch
//		Legal:			Copyright @2024, per MIT License below
//		Date:			May 13, 2024
//

// Apologies to purists, but I want simpler, clearer, shorter variable
// declarations (no "unsigned long long", etc.) 
// Type aliases:

typedef unsigned _int64 u64;
typedef unsigned int u32;
typedef unsigned long u32l;
typedef unsigned short u16;
typedef char u8;

typedef _int64 s64;
typedef int s32;
typedef short s16;

#define u64_Max UINT64_MAX
#define u32_Max UINT32_MAX
#define u16_Max UINT16_MAX

// The struct 'regs' is used in conjunction with unit tests
// It is used to verify that the non-volatile registers are not altered during calls to assembler routines.
// The Windows ABI (application binary interface) specifies which registers are for passing parameters, 
// which are ok to use without saving their values (volatile), and which must not be altered from whatever 
// values were in them when the caller called (non-volatile). The non-volatile may be used, but must be saved
// and restored before returning to the caller. Usually using the stack (either via push/pop or setting up a stack frame.)
// This struct, and the unit test routines verify those rules are followed.  It and the unit tests are not required
// after testing has been satisfied. (Not needed for production.)
//
struct regs {
	//  R12, R13, R14, R15, RDI, RSI, RBX, RBP, RSP 
	u64	R12;
	u64 R13;
	u64	R14;
	u64	R15;
	u64 RDI;
	u64 RSI;
	u64 RBX;
	u64 RBP;
	u64 RSP;

	// (Re) Initialize
	void Clear() {
		std::memset(this, 0, sizeof(regs));
	}

	// Compare two reg struct's values. Usually those values prior to call, with those values after call
	bool AreEqual(regs* rh) const {
		return !std::memcmp(this, rh, sizeof(regs));
	}
};

#endif