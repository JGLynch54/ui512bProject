//		ui512bTests
// 
//		File:			ui512bTests.cpp
//		Author:			John G.Lynch
//		Legal:			Copyright @2024, per MIT License below
//		Date:			June 11, 2024
//
//		ui512 is a small project to provide basic operations for a variable type of unsigned 512 bit integer.
//		The basic operations : zero, copy, compare, add, subtract.
//		Other optional modules provide bit ops and multiply / divide.
//		It is written in assembly language, using the MASM ( ml64 ) assembler provided as an option within Visual Studio.
//		( currently using VS Community 2022 17.9.6 )
//		It provides external signatures that allow linkage to C and C++ programs,
//		where a shell / wrapper could encapsulate the methods as part of an object.
//		It has assembly time options directing the use of Intel processor extensions : AVX4, AVX2, SIMD, or none :
//		( Z ( 512 ), Y ( 256 ), or X ( 128 ) registers, or regular Q ( 64bit ) ).
//		If processor extensions are used, the caller must align the variables declared and passed
//		on the appropriate byte boundary ( e.g. alignas 64 for 512 )
//		This module is very light - weight ( less than 1K bytes ) and relatively fast,
//		but is not intended for all processor types or all environments.
//		Use for private ( hobbyist ), or instructional,
//		or as an example for more ambitious projects is all it is meant to be.
// 
// 		ui512b provides basic bit-oriented operations: shift left, shift right, and, or, not,
//		least significant bit and most significant bit.
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

#include "ui512b.h"

using namespace std;
using namespace Microsoft::VisualStudio::CppUnitTestFramework;

namespace ui512bTests
{
	TEST_CLASS(ui512bTests)
	{
	public:

		const s32 runcount = 2500;
		const s32 timingcount = 1000000;

		/// <summary>
		/// Random number generator
		/// uses linear congruential method 
		/// ref: Knuth, Art Of Computer Programming, Vol. 2, Seminumerical Algorithms, 3rd Ed. Sec 3.2.1
		/// </summary>
		/// <param name="seed">if zero, will supply with: 4294967291</param>
		/// <returns>Pseudo-random number from zero to ~2^63 (9223372036854775807)</returns>
		u64 RandomU64(u64* seed)
		{
			const u64 m = 9223372036854775807ull;			// 2^63 - 1, a Mersenne prime
			const u64 a = 68719476721ull;					// closest prime below 2^36
			const u64 c = 268435399ull;						// closest prime below 2^28
			// suggested seed: around 2^32, 4294967291
			*seed = (*seed == 0ull) ? (a * 4294967291ull + c) % m : (a * *seed + c) % m;
			return *seed;
		};

		TEST_METHOD(random_number_generator)
		{
			//	Check distibution of "random" numbers
			u64 seed = 0;
			const u32 dec = 10;
			u32 dist[dec]{ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 };

			const u64 split = 9223372036854775807ull / dec;
			u32 distc = 0;
			float varsum = 0.0;
			float deviation = 0.0;
			float D = 0.0;
			float sumD = 0.0;
			float varience = 0.0;
			const u32 randomcount = 1000000;
			const s32 norm = randomcount / dec;
			for (u32 i = 0; i < randomcount; i++)
			{
				seed = RandomU64(&seed);
				dist[u64(seed / split)]++;
			};

			string msgd = "Evaluation of pseudo-random number generator.\n\n";
			msgd += format("Generated {0:*>8} numbers.\n", randomcount);
			msgd += format("Counted occurances of those numbers by decile, each decile {0:*>20}.\n", split);
			msgd += format("Distribution of numbers accross the deciles indicates the quality of the generator.\n\n");
			msgd += "Distribution by decile:";
			string msgv = "Variance from mean:\t";
			string msgchi = "Varience ^2 (chi):\t";

			for (int i = 0; i < 10; i++)
			{
				deviation = float(abs(long(norm) - long(dist[i])));
				D = (deviation * deviation) / float(long(norm));
				sumD += D;
				varience = float(deviation) / float(norm) * 100.0f;
				varsum += varience;
				msgd += format("\t{:6d}", dist[i]);
				msgv += format("\t{:5.3f}% ", varience);
				msgchi += format("\t{:5.3f}% ", D);
				distc += dist[i];
			};

			msgd += "\t\tDecile counts sum to: " + to_string(distc) + "\n";
			Logger::WriteMessage(msgd.c_str());
			msgv += "\t\tVarience sums to: ";
			msgv += format("\t{:6.3f}% ", varsum);
			msgv += '\n';
			Logger::WriteMessage(msgv.c_str());
			msgchi += "\t\tChi distribution: ";
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
			// shift into next word. Note: start validation at word 2 as most significant (index 0) word now zero
			shftcnt = 64;
			shr_u(num2, num1, shftcnt);
			Assert::AreEqual(num2[0], 0x0000000000000000ull);
			for (int j = 7; j > 0; j--)
			{
				Assert::AreEqual(0xFF00000000000000ull, num2[j]);
			};

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
			u16 shiftwalkcount = 1;
			for (int i = 0; i < 512; i++)
			{
				if (i == 63)
				{
					Logger::WriteMessage("Oops\n");
				}
				shr_u(wlk2, num3, i);
				for (int j = 7; j >= 0; j--)
				{
					if (wlk1[j] != wlk2[j])
					{
						string errmsg = "Shift right walk failed. shift count: "
							+ to_string(i)
							+ " word index: " + to_string(j);
						+" wlk1: " + to_string(wlk1[j])
							+ " wlk2: " + to_string(wlk2[j])
							+ ":\n";

						Logger::WriteMessage(errmsg.c_str());
					};
					Assert::AreEqual(wlk1[j], wlk2[j]);
				};

				if (i != 511)
				{
					shr_u(wlk1, wlk1, shiftwalkcount);
				};
			};

			Assert::AreEqual(1ull, wlk2[7]);
			Assert::AreEqual(1ull, wlk1[7]);

			string runmsg = "Shift right function testing. Ran tests " + to_string(517) + " times, with selected bit values.\n";
			Logger::WriteMessage(runmsg.c_str());
			Logger::WriteMessage(L"Passed. Tested expected values via assert.\n");
		};

		TEST_METHOD(ui512bits_01_shr_timing)
		{
			u64 seed = 0;
			alignas (64) u64 num1[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 num2[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			u16 shftcnt = 0;
			for (int i = 0; i < timingcount; i++)
			{
				for (int j = 0; j < 8; j++)
				{
					num1[j] = RandomU64(&seed);;
				};

				shftcnt = RandomU64(&seed) % 512;
				shr_u(num2, num1, shftcnt);
			};

			string runmsg = "Shift right function timing. Ran " + to_string(timingcount) + " times.\n";
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

			// walk a bit from most least significant to most
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
						string errmsg = "Shift left walk failed. shift count:"
							+ to_string(i)
							+ "wlk1: " + to_string(wlk1[j])
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

			string runmsg = "Shift left function testing" + to_string(517) + " times, with selected bit values.\n";
			Logger::WriteMessage(runmsg.c_str());
			Logger::WriteMessage(L"Passed. Tested expected values via assert.\n");
		};

		TEST_METHOD(ui512bits_02_shl_timing)
		{
			u64 seed = 0;
			alignas (64) u64 num1[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			alignas (64) u64 num2[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			u16 shftcnt = 0;
			for (int i = 0; i < timingcount; i++)
			{
				for (int j = 0; j < 8; j++)
				{
					num1[j] = RandomU64(&seed);;
				};

				shftcnt = RandomU64(&seed) % 512;
				shl_u(num2, num1, shftcnt);
			};

			string runmsg = "Shift left function timing. Ran " + to_string(timingcount) + " times.\n";
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
				for (int i = 0; i < 8; i++)
				{
					Assert::AreEqual(0x0ull, result[i]);
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
				for (int i = 0; i < 8; i++)
				{
					Assert::AreEqual(0xFFFFFFFFFFFFFFFFull, result[i]);
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
				for (int i = 0; i < 8; i++)
				{
					Assert::AreEqual(num2[i], result[i]);
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
				num1[j] = RandomU64(&seed);;
			};

			for (int i = 0; i < timingcount; i++)
			{
				not_u(num1, num1);
			};

			string runmsg = "NOT function timing. Ran " + to_string(timingcount) + " times.\n";
			Logger::WriteMessage(runmsg.c_str());
		};

		TEST_METHOD(ui512bits_06_msb)
		{
			u64 seed = 0;
			s16 bitloc = 0;
			s16 expectedbitloc = 0;
			int adjruncount = runcount / 64;
			alignas (64) u64 num1[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };

			for (int i = 0; i < adjruncount; i++)
			{
				for (int j = 0; j < 8; j++)
				{
					u64 val = 0x8000000000000000ull;
					for (int k = 0; k < 64; k++)
					{
						num1[j] = val;
						expectedbitloc = (j * 64) + k;
						bitloc = msb_u(num1);
						Assert::AreEqual(expectedbitloc, s16(511 - bitloc));
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
				num1[j] = RandomU64(&seed);;
			};

			for (int i = 0; i < timingcount; i++)
			{
				bitloc = msb_u(num1);
			};

			string runmsg = "MSB function timing. Ran " + to_string(timingcount) + " times.\n";
			Logger::WriteMessage(runmsg.c_str());
		};

		TEST_METHOD(ui512bits_07_lsb)
		{
			u64 seed = 0;
			s16 bitloc = 0;
			s16 expectedbitloc = 0;
			alignas (64) u64 num1[8]{ 0, 0, 0, 0, 0, 0, 0, 0 };
			int adjruncount = runcount / 64;

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
				num1[j] = RandomU64(&seed);;
			};

			for (int i = 0; i < timingcount; i++)
			{
				bitloc = lsb_u(num1);
			};

			string runmsg = "LSB function timing. Ran " + to_string(timingcount) + " times.\n";
			Logger::WriteMessage(runmsg.c_str());
		};
	};
}
