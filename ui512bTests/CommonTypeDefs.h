#pragma once
#ifndef CommonTypeDefs_h
#define CommonTypeDefs_h

//		CommonTypeDefs
// 
//		File:			CommonTypeDefs.cpp
//		Author:			John G.Lynch
//		Legal:			Copyright @2024, per MIT License below
//		Date:			June 11, 2024
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
#define u15_Max UINT16_MAX

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

	void Clear() {
		R12 = R13 = R14 = R15 = 0;
		RDI = RSI = RBX = RBP = 0;
		RSP = 0;
	}

	bool AreEqual(regs* rh)
	{
		if (this->R12 != rh->R12) return false;
		if (this->R13 != rh->R13) return false;
		if (this->R14 != rh->R14) return false;
		if (this->R15 != rh->R15) return false;
		if (this->RDI != rh->RDI) return false;
		if (this->R12 != rh->R12) return false;
		if (this->RSI != rh->RSI) return false;
		if (this->RBX != rh->RBX) return false;
		if (this->RBP != rh->RBP) return false;
		if (this->RSP != rh->RSP) return false;
		return true;
	}
};

#endif