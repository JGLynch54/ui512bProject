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

#endif