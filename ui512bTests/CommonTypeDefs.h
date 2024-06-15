#pragma once
#ifndef CommonTypeDefs_h
#define CommonTypeDefs_h

// Apologies to purists, but I want simpler, clearer, shorter variable
// declarations (no "unsigned long long", etc.) Type aliases

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
#define u15_Max UINT16_MAX#pragma once

#endif
