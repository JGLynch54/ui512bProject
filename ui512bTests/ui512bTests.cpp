//		ui512bTests
// 
//		File:			ui512bTests.cpp
//		Author:			John G.Lynch
//		Legal:			Copyright @2024, per MIT License below
//		Date:			June 11, 2024
//
//			Notes:
//				ui512 is a small project to provide basic operations for a variable type of unsigned 512 bit integer.
//
//				ui512a provides basic operations : zero, copy, compare, add, subtract.
//				ui512b provides basic bit - oriented operations : shift left, shift right, and, or , not, least significant bit and most significant bit.
//               ui512md provides multiply and divide.
//
//				It is written in assembly language, using the MASM(ml64) assembler provided as an option within Visual Studio.
//				(currently using VS Community 2022 17.14.10)
//
//				It provides external signatures that allow linkage to C and C++ programs,
//				where a shell / wrapper could encapsulate the methods as part of an object.
//
//				It has assembly time options directing the use of Intel processor extensions : AVX4, AVX2, SIMD, or none :
//				(Z(512), Y(256), or X(128) registers, or regular Q(64bit)).
//
//				If processor extensions are used, the caller must align the variables declared and passed
//				on the appropriate byte boundary(e.g. alignas 64 for 512)
//
//				This module is very light - weight(less than 2K bytes) and relatively fast,
//				but is not intended for all processor types or all environments.
//
//				Use for private (hobbyist), or instructional, or as an example for more ambitious projects.
//
//		This sub - project: ui512aTests, is a unit test project that invokes each of the routines in the ui512a assembly.
//		It runs each assembler proc with pseudo - random values.
//		It validates ( asserts ) expected and returned results.
//		It also runs each repeatedly for comparative timings.
//		It provides a means to invoke and debug.
//		It illustrates calling the routines from C++.

#include "pch.h"
#include "CppUnitTest.h"

#include <format>

#include "ui512a.h"
#include "ui512b.h"

using namespace std;
using namespace Microsoft::VisualStudio::CppUnitTestFramework;

namespace ui512bTests
{
	TEST_CLASS(ui512bTests)
	{
	public:

		const s32 runcount = 2500;
		const s32 regvercount = 5000;
		const s32 timingcount = 100000000;

		/// <summary>
		/// Random number generator
		/// uses linear congruential method 
		/// ref: Knuth, Art Of Computer Programming, Vol. 2, Seminumerical Algorithms, 3rd Ed. Sec 3.2.1
		/// </summary>
		/// Note: I use this rather than built-in random functions because it produces repeatable results. Handy for debugging.
		/// <param name="seed">if zero, will supply with: 4294967291</param>
		/// <returns>Pseudo-random number from zero to ~2^64 (18446744073709551557)</returns>
		u64 RandomU64(u64* seed)
		{
			const u64 m = 18446744073709551557ull;			// greatest prime below 2^64
			const u64 a = 68719476721ull;					// closest prime below 2^36
			const u64 c = 268435399ull;						// closest prime below 2^28
			// suggested seed: around 2^32, 4294967291
			*seed = (*seed == 0ull) ? (a * 4294967291ull + c) % m : (a * *seed + c) % m;
			return *seed;
		};

		TEST_METHOD(random_number_generator)
		{
			//	Check distribution of "random" numbers
			u64 seed = 0;
			const u32 dec = 10;
			u32 dist[dec]{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

			const u64 split = 18446744073709551557ull / dec;
			u32 distc = 0;
			float varsum = 0.0;
			float deviation = 0.0;
			float D = 0.0;
			float sumD = 0.0;
			float variance = 0.0;
			const u32 randomcount = 1000000;
			const s32 norm = randomcount / dec;
			for (u32 i = 0; i < randomcount; i++)
			{
				seed = RandomU64(&seed);
				dist[u64(seed / split)]++;
			};

			string msgd = "Evaluation of pseudo-random number generator.\n\n";
			msgd += format("Generated {0:*>8} numbers.\n", randomcount);
			msgd += format("Counted occurrences of those numbers by decile, each decile {0:*>20}.\n", split);
			msgd += format("Distribution of numbers across the deciles indicates the quality of the generator.\n\n");
			msgd += "Distribution by decile:";
			string msgv = "Variance from mean:\t";
			string msgchi = "Variance ^2 (chi):\t";

			for (int i = 0; i < 10; i++)
			{
				deviation = float(abs(long(norm) - long(dist[i])));
				D = (deviation * deviation) / float(long(norm));
				sumD += D;
				variance = float(deviation) / float(norm) * 100.0f;
				varsum += variance;
				msgd += format("\t{:6d}", dist[i]);
				msgv += format("\t{:5.3f}% ", variance);
				msgchi += format("\t{:5.3f}% ", D);
				distc += dist[i];
			};

			msgd += "\t\tDecile counts sum to: " + to_string(distc) + "\n";
			Logger::WriteMessage(msgd.c_str());
			msgv += "\t\tVariance sums to: ";
			msgv += format("\t{:6.3f}% ", varsum);
			msgv += '\n';
			Logger::WriteMessage(msgv.c_str());
			msgchi += "\t\tChi-squared distribution: ";
			msgchi += format("\t{:6.3f}% ", sumD);
			msgchi += '\n';
			Logger::WriteMessage(msgchi.c_str());
		};

		TEST_METHOD(ui512bits_01_shr)
		{
			u64 seed = 0;
			alignas (64) u64 num1[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 num2[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			u16 shftcnt = 0;
			for (int j = 0; j < 8; j++)
			{
				num1[j] = 0xFF00000000000000ull;
			};
			// shift within each word to the end of the word
			shftcnt = 64 - 8;
			shr_u(num2, num1, shftcnt);
			for (int j = 0; j < 8; j++)
			{
				Assert::AreEqual(0x00000000000000FFull, num2[j]);
			};
			string runmsg2 = "Shift right function testing. Shift ff within each word to the end of each word.\n";
			Logger::WriteMessage(runmsg2.c_str());
			Logger::WriteMessage(L"Passed. Tested expected values via assert.\n");

			// shift into next word. Note: start validation at word 2 as most significant (index 0) word now zero
			shftcnt = 64;
			shr_u(num2, num1, shftcnt);
			Assert::AreEqual(num2[0], 0x0000000000000000ull);
			for (int j = 7; j > 0; j--)
			{
				Assert::AreEqual(0xFF00000000000000ull, num2[j]);
			};
			string runmsg3 = "Shift right function testing. Shift ff into next word.\n";
			Logger::WriteMessage(runmsg3.c_str());
			Logger::WriteMessage(L"Passed. Tested expected values via assert.\n");
			// run same tests, with destination same as source, note: second test works on results of first now
			for (int j = 0; j < 8; j++)
			{
				num1[j] = 0xFF00000000000000ull;
			};
			shftcnt = 64 - 8;
			shr_u(num1, num1, shftcnt);
			for (int j = 0; j < 8; j++)
			{
				Assert::AreEqual(0x00000000000000FFull, num1[j]);
			};
			string runmsg4 = "Shift right function testing. Shift ff into next word. Destination same as source\n";
			Logger::WriteMessage(runmsg4.c_str());
			Logger::WriteMessage(L"Passed. Tested expected values via assert.\n");
			// shift into next word. Note: start at word 2 as first word now zero
			shftcnt = 64;
			shr_u(num1, num1, shftcnt);
			Assert::AreEqual(0x0000000000000000ull, num1[0]);
			for (int j = 7; j >= 1; j--)
			{
				Assert::AreEqual(0x00000000000000FFull, num1[j]);
			};

			// walk a bit from most significant to least
			alignas (64) u64 num3[8]{ 0x8000000000000000ull, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 wlk1[8]{ 0x8000000000000000ull, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 wlk2[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			shr_u(wlk2, num3, 0); // essentially a copy: wlk2 now equal to num3
			for (int i = 1; i < 512; i++)
			{
				for (int j = 7; j >= 0; j--)
				{
					if (wlk1[j] != wlk2[j])
					{
						string errmsg = "Shift right walk failed. shift count: "
							+ to_string(i)
							+ " word index: " + to_string(j)
							+ " wlk1: " + to_string(wlk1[j])
							+ " wlk2: " + to_string(wlk2[j])
							+ ":\n";

						Logger::WriteMessage(errmsg.c_str());
					};
					Assert::AreEqual(wlk1[j], wlk2[j]);
				};
				shr_u(wlk1, num3, i);	// shift from original source 'n' bits
				shr_u(wlk2, wlk2, 1);	// shift from last shift one more bit (should be equal)
			};

			Assert::AreEqual(1ull, wlk2[7]);		// end of bit by bit walk, should be one
			Assert::AreEqual(1ull, wlk1[7]);		// end of a 511 shift, should be one
			string runmsg5 = "Shift right function testing. Walk a bit from msb to lsb. Verify values each step\n";
			Logger::WriteMessage(runmsg5.c_str());
			Logger::WriteMessage(L"Passed. Tested expected values via assert.\n");

			string runmsg = "Shift right function testing. Ran tests " + to_string(4 + 512 + 511) + " times, with selected bit values.\n";
			Logger::WriteMessage(runmsg.c_str());
			Logger::WriteMessage(L"Passed. Tested expected values via assert.\n");
		};

		TEST_METHOD(ui512bits_01_shr_timing)
		{
			u64 seed = 0;
			alignas (64) u64 num1[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 num2[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			u16 shftcnt = 0;
			for (int j = 0; j < 8; j++)
			{
				num1[j] = RandomU64(&seed);;
			};

			shftcnt = RandomU64(&seed) % 512;

			for (int i = 0; i < timingcount; i++)
			{

				shr_u(num2, num1, shftcnt);
			};

			string runmsg = "Shift right function timing. Ran " + to_string(timingcount) + " times.\n";
			Logger::WriteMessage(runmsg.c_str());
		};

		TEST_METHOD(ui512bits_01_SHR_reg)
		{
			// shr_u function register verification.
			//	Check register before call, verify non-volatile register remain unchanged after call.
			regs r_before{};
			regs r_after{};
			u64 seed = 0;
			alignas (64) u64 num1[8]{};
			alignas (64) u64 num2[8]{};
			alignas (64) u64 num3[8]{};
			for (int i = 0; i < regvercount; i++)
			{
				for (int j = 0; j < 8; j++)
				{
					num2[j] = RandomU64(&seed);
					num3[j] = RandomU64(&seed);
				};
				u64 val = RandomU64(&seed);
				r_before.Clear();
				reg_verify((u64*)&r_before);
				shr_u(num1, num2, 127);
				r_after.Clear();
				reg_verify((u64*)&r_after);
				Assert::IsTrue(r_before.AreEqual(&r_after), L"Register validation failed");
			};

			string runmsg = "shr_u function register validation. Ran " + to_string(regvercount) + " times.\n";
			Logger::WriteMessage(runmsg.c_str());
		};

		TEST_METHOD(ui512bits_02_shl)
		{
			u64 seed = 0;
			alignas (64) u64 num1[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 num2[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			u16 shftcnt = 0;
			for (int j = 0; j < 8; j++)
			{
				num1[j] = 0x00000000000000FFull;
			};
			// shift left within each word to the beginning of the word
			shftcnt = 64 - 8;
			shl_u(num2, num1, shftcnt);
			for (int j = 0; j < 8; j++)
			{
				Assert::AreEqual(num2[j], 0xFF00000000000000ull);
			};
			// shift into next word. Note: start validation at word 2 as least significant (index 7) word now zero
			shftcnt = 64;
			shl_u(num2, num1, shftcnt);
			Assert::AreEqual(num2[7], 0x0000000000000000ull);
			for (int j = 6; j >= 0; j--)
			{
				Assert::AreEqual(num2[j], 0x00000000000000FFull);
			};

			// run same tests, with destination same as source, note: second test works on results of first now
			for (int j = 0; j < 8; j++)
			{
				num1[j] = 0x00000000000000FFull;
			};
			shftcnt = 64 - 8;
			shl_u(num1, num1, shftcnt);
			for (int j = 0; j < 8; j++)
			{
				Assert::AreEqual(num1[j], 0xFF00000000000000ull);
			};
			// shift into next word. Note: start at word 2 as first word now zero
			shftcnt = 64;
			shl_u(num1, num1, shftcnt);
			Assert::AreEqual(num1[7], 0x0000000000000000ull);
			for (int j = 6; j >= 0; j--)
			{
				Assert::AreEqual(num1[j], 0xFF00000000000000ull);
			};

			// walk a bit from least significant to most
			alignas (64) u64 num3[8]{ 0, 0, 0, 0, 0, 0, 0, 1 };
			alignas (64) u64 wlk1[8]{ 0, 0, 0, 0, 0, 0, 0, 1 };
			alignas (64) u64 wlk2[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			u16 shiftwalkcount = 1;
			for (int i = 0; i < 512; i++)
			{
				shl_u(wlk2, num3, i);
				for (int j = 7; j >= 0; j--)
				{
					if (wlk1[j] != wlk2[j])
					{
						string errmsg = "Shift left walk failed. shift count: "
							+ to_string(i)
							+ " wlk1: " + to_string(wlk1[j])
							+ " wlk2: " + to_string(wlk2[j])
							+ ":\n";

						Logger::WriteMessage(errmsg.c_str());
					};

					Assert::AreEqual(wlk1[j], wlk2[j]);
				};

				if (i != 511)
				{
					shl_u(wlk1, wlk1, shiftwalkcount);
				};
			};

			Assert::AreEqual(0x8000000000000000ull, wlk2[0]);
			Assert::AreEqual(0x8000000000000000ull, wlk1[0]);

			string runmsg = "Shift left function testing. Ran tests " + to_string(4 + 512 + 511) + " times, with selected bit values.\n";
			Logger::WriteMessage(runmsg.c_str());
			Logger::WriteMessage(L"Passed. Tested expected values via assert.\n");
		};

		TEST_METHOD(ui512bits_02_shl_timing)
		{
			u64 seed = 0;
			alignas (64) u64 num1[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 num2[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			u16 shftcnt = 0;
			for (int j = 0; j < 8; j++)
			{
				num1[j] = RandomU64(&seed);;
			};

			shftcnt = RandomU64(&seed) % 512;
			for (int i = 0; i < timingcount; i++)
			{
				shl_u(num2, num1, shftcnt);
			};

			string runmsg = "Shift left function timing. Ran " + to_string(timingcount) + " times.\n";
			Logger::WriteMessage(runmsg.c_str());
		};

		TEST_METHOD(ui512bits_02_SHL_reg)
		{
			// shl_u function register verification.
			//	Check register before call, verify non-volatile register remain unchanged after call.
			regs r_before{};
			regs r_after{};
			u64 seed = 0;
			alignas (64) u64 num1[8]{};
			alignas (64) u64 num2[8]{};
			alignas (64) u64 num3[8]{};
			for (int i = 0; i < regvercount; i++)
			{
				for (int j = 0; j < 8; j++)
				{
					num2[j] = RandomU64(&seed);
					num3[j] = RandomU64(&seed);
				};
				u64 val = RandomU64(&seed);
				r_before.Clear();
				reg_verify((u64*)&r_before);
				shl_u(num1, num2, 213);
				r_after.Clear();
				reg_verify((u64*)&r_after);
				Assert::IsTrue(r_before.AreEqual(&r_after), L"Register validation failed");
			};

			string runmsg = "shl_u function register validation. Ran " + to_string(regvercount) + " times.\n";
			Logger::WriteMessage(runmsg.c_str());
		};

		TEST_METHOD(ui512bits_03_and)
		{
			u64 seed = 0;
			alignas (64) u64 num1[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 num2[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 result[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			for (int i = 0; i < runcount; i++)
			{
				for (int j = 0; j < 8; j++)
				{
					num1[j] = RandomU64(&seed);
					num2[j] = ~num1[j];
					result[j] = 0;
				};

				and_u(result, num1, num2);
				for (int j = 0; j < 8; j++)
				{
					Assert::AreEqual(0x0ull, result[j]);
				};
			};

			string runmsg = "'AND' function testing. Ran tests " + to_string(runcount) + " times, each with pseudo random values.\n";
			Logger::WriteMessage(runmsg.c_str());
			Logger::WriteMessage(L"Passed. Tested expected values via assert.\n");
		};

		TEST_METHOD(ui512bits_03_and_timing)
		{
			u64 seed = 0;
			alignas (64) u64 num1[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 num2[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 result[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			for (int j = 0; j < 8; j++)
			{
				num1[j] = RandomU64(&seed);
				num2[j] = RandomU64(&seed);
			};

			for (int i = 0; i < timingcount; i++)
			{
				and_u(result, num2, num1);
			};

			string runmsg = "'AND' function timing. Ran " + to_string(timingcount) + " times.\n";
			Logger::WriteMessage(runmsg.c_str());
		};

		TEST_METHOD(ui512bits_03_AND_reg)
		{
			// and_u function register verification.
			//	Check register before call, verify non-volatile register remain unchanged after call.
			regs r_before{};
			regs r_after{};
			u64 seed = 0;
			alignas (64) u64 num1[8]{};
			alignas (64) u64 num2[8]{};
			alignas (64) u64 num3[8]{};
			for (int i = 0; i < regvercount; i++)
			{
				for (int j = 0; j < 8; j++)
				{
					num2[j] = RandomU64(&seed);
					num3[j] = RandomU64(&seed);
				};
				u64 val = RandomU64(&seed);
				r_before.Clear();
				reg_verify((u64*)&r_before);
				and_u(num1, num2, num3);
				r_after.Clear();
				reg_verify((u64*)&r_after);
				Assert::IsTrue(r_before.AreEqual(&r_after), L"Register validation failed");
			};

			string runmsg = "and_u function register validation. Ran " + to_string(regvercount) + " times.\n";
			Logger::WriteMessage(runmsg.c_str());
		};

		TEST_METHOD(ui512bits_04_or)
		{
			u64 seed = 0;
			alignas (64) u64 num1[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 num2[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 result[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			for (int i = 0; i < runcount; i++)
			{
				for (int j = 0; j < 8; j++)
				{
					num1[j] = RandomU64(&seed);
					num2[j] = ~num1[j];
					result[j] = 0;
				};

				or_u(result, num1, num2);
				for (int j = 0; j < 8; j++)
				{
					Assert::AreEqual(0xFFFFFFFFFFFFFFFFull, result[j]);
				};
			};
			string runmsg = "'OR' function testing. Ran tests " + to_string(runcount) + " times, each with pseudo random values.\n";
			Logger::WriteMessage(runmsg.c_str());
			Logger::WriteMessage(L"Passed. Tested expected values via assert.\n");
		};

		TEST_METHOD(ui512bits_04_or_timing)
		{
			u64 seed = 0;
			alignas (64) u64 num1[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 num2[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 result[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };

			for (int j = 0; j < 8; j++)
			{
				num1[j] = RandomU64(&seed);
				num2[j] = RandomU64(&seed);
			};

			for (int i = 0; i < timingcount; i++)
			{
				or_u(result, num2, num1);
			};

			string runmsg = "'OR' function timing. Ran " + to_string(timingcount) + " times.\n";
			Logger::WriteMessage(runmsg.c_str());
		};

		TEST_METHOD(ui512bits_04_OR_reg)
		{
			// or_u function register verification.
			//	Check register before call, verify non-volatile register remain unchanged after call.
			regs r_before{};
			regs r_after{};
			u64 seed = 0;
			alignas (64) u64 num1[8]{};
			alignas (64) u64 num2[8]{};
			for (int i = 0; i < regvercount; i++)
			{
				for (int j = 0; j < 8; j++)
				{
					num1[j] = RandomU64(&seed);
					num2[j] = RandomU64(&seed);
				};
				r_before.Clear();
				reg_verify((u64*)&r_before);
				or_u(num2, num2, num1);
				r_after.Clear();
				reg_verify((u64*)&r_after);
				Assert::IsTrue(r_before.AreEqual(&r_after), L"Register validation failed");
			};

			string runmsg = "or_u function register validation. Ran " + to_string(regvercount) + " times.\n";
			Logger::WriteMessage(runmsg.c_str());
		};


		TEST_METHOD(ui512bits_04_xor)
		{
			u64 seed = 0;
			alignas (64) u64 num1[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 num2[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 result[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			for (int i = 0; i < runcount; i++)
			{
				for (int j = 0; j < 8; j++)
				{
					num1[j] = num2[j] = RandomU64(&seed);
					result[j] = 0;
				};

				xor_u(result, num1, num2);
				for (int j = 0; j < 8; j++)
				{
					Assert::AreEqual(0x0ull, result[j]);
				};
			};
			string runmsg = "'XOR' function testing. Ran tests " + to_string(runcount) + " times, each with pseudo random values.\n";
			Logger::WriteMessage(runmsg.c_str());
			Logger::WriteMessage(L"Passed. Tested expected values via assert.\n");
		};

		TEST_METHOD(ui512bits_04_xor_timing)
		{
			u64 seed = 0;
			alignas (64) u64 num1[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 num2[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 result[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };

			for (int j = 0; j < 8; j++)
			{
				num1[j] = RandomU64(&seed);
				num2[j] = RandomU64(&seed);
			};

			for (int i = 0; i < timingcount; i++)
			{
				xor_u(result, num2, num1);
			};

			string runmsg = "'XOR' function timing. Ran " + to_string(timingcount) + " times.\n";
			Logger::WriteMessage(runmsg.c_str());
		};

		TEST_METHOD(ui512bits_04_XOR_reg)
		{
			// xor_u function register verification.
			//	Check register before call, verify non-volatile register remain unchanged after call.
			regs r_before{};
			regs r_after{};
			u64 seed = 0;
			alignas (64) u64 num1[8]{};
			alignas (64) u64 num2[8]{};
			for (int i = 0; i < regvercount; i++)
			{
				for (int j = 0; j < 8; j++)
				{
					num1[j] = RandomU64(&seed);
					num2[j] = RandomU64(&seed);
				};
				r_before.Clear();
				reg_verify((u64*)&r_before);
				xor_u(num2, num2, num1);
				r_after.Clear();
				reg_verify((u64*)&r_after);
				Assert::IsTrue(r_before.AreEqual(&r_after), L"Register validation failed");
			};

			string runmsg = "xor_u function register validation. Ran " + to_string(regvercount) + " times.\n";
			Logger::WriteMessage(runmsg.c_str());
		};
		TEST_METHOD(ui512bits_05_not)
		{
			u64 seed = 0;
			alignas (64) u64 num1[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 num2[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 result[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			for (int i = 0; i < runcount; i++)
			{

				for (int j = 0; j < 8; j++)
				{
					num1[j] = RandomU64(&seed);
					num2[j] = ~num1[j];
					result[j] = 0;
				};

				not_u(result, num1);
				for (int j = 0; j < 8; j++)
				{
					Assert::AreEqual(num2[j], result[j]);
				};
			};
			string runmsg = "'NOT' function testing. Ran tests " + to_string(runcount) + " times, each with pseudo random values.\n";
			Logger::WriteMessage(runmsg.c_str());
			Logger::WriteMessage(L"Passed. Tested expected values via assert.\n");
		};

		TEST_METHOD(ui512bits_05_not_timing)
		{
			u64 seed = 0;
			alignas (64) u64 num1[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			for (int j = 0; j < 8; j++)
			{
				num1[j] = RandomU64(&seed);
			};

			for (int i = 0; i < timingcount; i++)
			{
				not_u(num1, num1);
			};

			string runmsg = "NOT function timing. Ran " + to_string(timingcount) + " times.\n";
			Logger::WriteMessage(runmsg.c_str());
		};


		TEST_METHOD(ui512bits_05_NOT_reg)
		{
			// not_u function register verification.
			//	Check register before call, verify non-volatile register remain unchanged after call.
			regs r_before{};
			regs r_after{};
			u64 seed = 0;
			alignas (64) u64 num1[8]{};
			alignas (64) u64 num2[8]{};
			for (int i = 0; i < regvercount; i++)
			{
				for (int j = 0; j < 8; j++)
				{
					num1[j] = RandomU64(&seed);
					num2[j] = RandomU64(&seed);
				};
				r_before.Clear();
				reg_verify((u64*)&r_before);
				not_u(num2, num1);
				r_after.Clear();
				reg_verify((u64*)&r_after);
				Assert::IsTrue(r_before.AreEqual(&r_after), L"Register validation failed");
			};

			string runmsg = "not_u function register validation. Ran " + to_string(regvercount) + " times.\n";
			Logger::WriteMessage(runmsg.c_str());
		};

		TEST_METHOD(ui512bits_06_msb)
		{
			u64 seed = 0;
			s16 bitloc = 0;
			s16 expectedbitloc = 0;
			int adjruncount = runcount / 64;

			alignas (64) u64 num1[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };

			alignas (64) u64 highbit[8]{ 0x8000000000000000, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 lowbit[8]{ 0, 0, 0, 0, 0, 0, 0, 1 };
			alignas (64) u64 b2bit[8]{ 0, 0, 0, 0, 0, 0, 0, 2 };
			alignas (64) u64 nobit[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 choosebit[8]{ 0, 9, 0, 0, 0, 0x8000000000000000, 0xff, 0 };

			s16 highbitloc = msb_u(highbit);
			Assert::AreEqual(s16(511), highbitloc);

			s16 lowbitloc = msb_u(lowbit);
			Assert::AreEqual(s16(0), lowbitloc);

			s16 b2bitloc = msb_u(b2bit);
			Assert::AreEqual(s16(1), b2bitloc);

			s16 nobitloc = msb_u(nobit);
			Assert::AreEqual(s16(-1), nobitloc);

			s16 choosebitloc = msb_u(choosebit);
			Assert::AreEqual(s16(387), choosebitloc);

			for (int i = 0; i < adjruncount; i++)
			{
				for (int j = 0; j < 8; j++)
				{
					u64 val = 0x8000000000000000ull;
					for (int k = 0; k < 64; k++)
					{
						num1[j] = val;
						expectedbitloc = 511 - ((j * 64) + k);
						bitloc = msb_u(num1);
						Assert::AreEqual(expectedbitloc, bitloc);
						val = val >> 1;
					};

					num1[j] = 0;
				};

			};

			string runmsg = "Most significant bit function testing. Ran tests " + to_string(runcount) + " times, each with shifted values.\n";
			Logger::WriteMessage(runmsg.c_str());
			Logger::WriteMessage(L"Passed. Tested expected values via assert.\n");
		};

		TEST_METHOD(ui512bits_06_msb_timing)
		{
			u64 seed = 0;
			alignas (64) u64 num1[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			s16 bitloc = 0;

			for (int j = 0; j < 8; j++)
			{
				num1[j] = RandomU64(&seed);
			};

			for (int i = 0; i < timingcount; i++)
			{
				bitloc = msb_u(num1);
			};

			string runmsg = "MSB function timing. Ran " + to_string(timingcount) + " times.\n";
			Logger::WriteMessage(runmsg.c_str());
		};

		TEST_METHOD(ui512bits_06_msb_reg)
		{
			// msb_u function register verification.
			//	Check register before call, verify non-volatile register remain unchanged after call.
			regs r_before{};
			regs r_after{};
			u64 seed = 0;
			alignas (64) u64 num1[8]{};
			for (int i = 0; i < regvercount; i++)
			{
				for (int j = 0; j < 8; j++)
				{
					num1[j] = RandomU64(&seed);
				};
				r_before.Clear();
				reg_verify((u64*)&r_before);
				s16 result = msb_u(num1);
				r_after.Clear();
				reg_verify((u64*)&r_after);
				Assert::IsTrue(r_before.AreEqual(&r_after), L"Register validation failed");
			};

			string runmsg = "msb_u function register validation. Ran " + to_string(regvercount) + " times.\n";
			Logger::WriteMessage(runmsg.c_str());
		};

		TEST_METHOD(ui512bits_07_lsb)
		{
			u64 seed = 0;
			s16 bitloc = 0;
			s16 expectedbitloc = 0;
			alignas (64) u64 num1[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			int adjruncount = runcount / 64;

			alignas (64) u64 highbit[8]{ 0x8000000000000000, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 lowbit[8]{ 0, 0, 0, 0, 0, 0, 0, 1 };
			alignas (64) u64 b2bit[8]{ 0, 0, 0, 0, 0, 0, 0, 2 };
			alignas (64) u64 nobit[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 choosebit[8]{ 0, 1, 0, 0, 0, 0x8000000000000000, 0, 0 };

			s16 highbitloc = lsb_u(highbit);
			Assert::AreEqual(s16(511), highbitloc);

			s16 lowbitloc = lsb_u(lowbit);
			Assert::AreEqual(s16(0), lowbitloc);

			s16 b2bitloc = lsb_u(b2bit);
			Assert::AreEqual(s16(1), b2bitloc);

			s16 nobitloc = lsb_u(nobit);
			Assert::AreEqual(s16(-1), nobitloc);

			s16 choosebitloc = lsb_u(choosebit);
			Assert::AreEqual(s16(191), choosebitloc);

			for (int i = 0; i < adjruncount; i++)
			{
				for (int j = 7; j >= 0; j--)
				{
					u64 val = 1;
					for (int k = 63; k >= 0; k--)
					{
						num1[j] = val;
						expectedbitloc = 511 - (j * 64 + k);
						bitloc = lsb_u(num1);
						Assert::AreEqual(expectedbitloc, bitloc);
						val = val << 1;
					};

					num1[j] = 0;
				};

			};

			string runmsg = "Least significant bit function testing. Ran tests " + to_string(runcount) + " times, each with shifted values.\n";
			Logger::WriteMessage(runmsg.c_str());
			Logger::WriteMessage(L"Passed. Tested expected values via assert.\n");
		};

		TEST_METHOD(ui512bits_07_lsb_timing)
		{
			u64 seed = 0;
			alignas (64) u64 num1[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			s16 bitloc = 0;

			for (int j = 0; j < 8; j++)
			{
				num1[j] = RandomU64(&seed);
			};

			for (int j = 0; j < timingcount; j++)
			{
				bitloc = lsb_u(num1);
			};

			string runmsg = "LSB function timing. Ran " + to_string(timingcount) + " times.\n";
			Logger::WriteMessage(runmsg.c_str());
		};

		TEST_METHOD(ui512bits_07_lsb_reg)
		{
			// lsb_u function register verification.
			//	Check register before call, verify non-volatile register remain unchanged after call.
			regs r_before{};
			regs r_after{};
			u64 seed = 0;
			alignas (64) u64 num1[8]{};
			for (int i = 0; i < regvercount; i++)
			{
				for (int j = 0; j < 8; j++)
				{
					num1[j] = RandomU64(&seed);
				};
				r_before.Clear();
				reg_verify((u64*)&r_before);
				s16 result = lsb_u(num1);
				r_after.Clear();
				reg_verify((u64*)&r_after);
				Assert::IsTrue(r_before.AreEqual(&r_after), L"Register validation failed");
			};

			string runmsg = "lsb_u function register validation. Ran " + to_string(regvercount) + " times.\n";
			Logger::WriteMessage(runmsg.c_str());
		};
	};
}
