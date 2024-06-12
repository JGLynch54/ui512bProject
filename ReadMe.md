Project Description

	ui512 is a small project to provide basic operations for a variable type of unsigned 512 bit integer.
	The basic operations in the module ui512a are: zero, copy, compare, add, subtract.
    Other optional modules provide bit ops and multiply / divide.
	It is written in assembly language, using the MASM (ml64) assembler provided as an option within 
    Visual Studio (currently using VS Community 2022 17.9.6).
	It provides external signatures that allow linkage to C and C++ programs, where a shell/wrapper
    could encapsulate the methods as part of an object.
	It has assembly time options directing the use of Intel processor extensions:
    AVX4, AVX2, SIMD, or none: (Z (512), Y (256), or X (128) registers, or regular Q (64bit))
	If processor extensions are used, the caller must align the variables declared and passed on the 
    appropriate byte boundary (e.g. alignas 64 for 512)
	This module is very light-weight (less than 1K bytes) and relatively fast, but is not intended
    for all processor types or all environments. 
	Use for private (hobbyist), or instructional, or as an example for more ambitious projects is
    all it is meant to be.

	ui512b provides basic bit-oriented operations: shift left, shift right, and, or, not,
    least significant bit and most significant bit.

Installation Instructions

    A.) Set up Visual Studio environment.
		Ref: https://www.wikihow.com/Use-MASM-in-Visual-Studio-2022
		Ref: https://learn.microsoft.com/en-us/cpp/assembler/masm/masm-for-x64-ml64-exe?view=msvc-170
		Ref: https://programminghaven.home.blog/2020/02/16/setup-an-assembly-project-on-visual-studio-2019/

		I also use ASMDude2 from https://marketplace.visualstudio.com/items?itemName=Henk-JanLebbink.AsmDude2
		You can install that through "Extensions, Manage Extensions, Online, MarketPlace, Tools, search "AsmDude2".

		It is not necessary, but provides syntax highlighting and mnemonic assistance with asm code.
		Also instruction performance characteristics.

	B.) Set up or copy project directories, add as project and or solution to new, blank project under Visual Studio
		solution explorer.

		Get VS to recognize .asm in general, and your files in particular:

			Right click project name.
			Select "Build Dependencies, Build Customization"
			Select (check) masm (.tagets, .props), Click OK
			Project can now include assembler code.

		Right click on source file "ui52a.asm"
		Select Item Type (probably current value "Does not participate in build"
		Click drop down button on right, Select "Microsoft Macro Assembler"
		Click Excluded from Build, Set to "NO"
		Click "Apply"
		The source code file is now recognized as partipating in the build, and of type assembler.

Usage Guidelines

    For this project, build a library to be included in another build such as a unit test program,
	a "C" program, or a "C++" program.
		Right click project name. Select properties.
		Under General Properties, Configuration Type, Select drop down, select "Static Library (.lib)",
		Click "Apply"
		Under Librarian, General, Select Output FIle, CLick Edit,
		and type:	$(SolutionDir)$(TargetName)$(TargetExt)
	This places your compiled library file (to include as an additional library
	to link in your host project), in the solution directory.

	Get a listing of your assembly. This is not necessary, but I like to look at the assembled code
	(old school tendency, where we debugged from listings and opcodes).
		Right click project name, Select Properties.
		Select Microsoft Macro Assembler, Expand it (the little arrow), Select Listing file.
		Select Enable Assembly Generated Code Listing, click drop down selector, select "YES (/Sg)",
		Click Apply.
		Select Assembled Code Listing File. Use drop down arrow, select "Edit .."
		Type in "$(IntDir)%(FileName).cod" Click OK, Click Apply.
		
	Click on the solution name in solution explorer..
		Click on the Visual Studio main menu: Build, Select Rebuild.
		Hopefully all the settings, copying, and environment setup results in a clean build. If not,
		go back and see what you missed.

		In solution explorer, right click on the project name. Select "Open Folder in File Explorer"
		In file explorer, navigate to project name, x64, debug.
		Double click on ui512a.cod (your assembled code listing)

	Your .lib file is ready to be included in whatever project. It is under your project file directory,
	x64, debug, projectname.lib
	You can copy it, or refer to it in your other project build by directoryname/filename in the 
	link section of the other build. 
	In the other build: Properties, Linker, Input, Additional dependencies, Edit: Add path,
	filename to your new library.

	Don't forget to put something in a header file that looks something like this:

	// Apologies to purists, but I want simpler, clearer, shorter variable declarations
	// (no "unsigned long long", etc.) 
	// Type aliases

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

	extern "C"
	{
		// Note:  Unless assembled with "__UseQ", all of the u64* arguments passed must be 64 byte aligned (alignas 64); GP fault will occur if not 

		//	Procedures from ui512b.asm module:
		//	EXTERN "C" signatures

		// shift supplied source 512bit (8 QWORDS) right, put in destination
		// void shr_u ( u64* destination, u64* source, u32 bits_to_shift )
		void shr_u ( u64*,  u64*, u32 );

		// shift supplied source 512bit (8 QWORDS) left, put in destination
	    // void shl_u ( u64* destination, u64* source, u16 bits_to_shift );
		void shl_u ( u64*, u64*, u16 );

		// logical 'AND' bits in lh_op, rh_op, put result in destination
		// void and_u ( u64* destination, u64* lh_op, u64* rh_op );
		void and_u ( u64*, u64*, u64* );

		// logical 'OR' bits in lh_op, rh_op, put result in destination
		// void or_u( u64* destination, u64* lh_op, u64* rh_op);
		void or_u( u64*, u64*, u64* );

		// logical 'NOT' bits in source, put result in destination
		// void not_u( u64* destination, u64* source);
		void not_u( u64* destination, u64* source);

		// find most significant bit in supplied source 512bit (8 QWORDS)
		// s16 msb_u( u64* );
		// returns: -1 if no most significant bit, bit number otherwise, bits numbered 0 to 511 inclusive
		s16 msb_u( u64* );

		// find least significant bit in supplied source 512bit (8 QWORDS)
		// s16 lsb_u( u64* );
		// returns: -1 if no least significant bit, bit number otherwise, bits numbered 0 to 511 inclusive
		s16 lsb_u( u64* );
	};

Contributing

    I'm interested in ways to improve the code, feel free to suggest, revise.


License

	MIT License

		Copyright (c) 2024 John G. Lynch
			Permission is hereby granted, free of charge, to any person obtaining a copy
			of this software and associated documentation files (the "Software"), to deal
			in the Software without restriction, including without limitation the rights
			to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
			copies of the Software, and to permit persons to whom the Software is
			furnished to do so, subject to the following conditions:

			The above copyright notice and this permission notice shall be included in all
			copies or substantial portions of the Software.

			THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
			IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
			FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
			AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
			LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
			OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
			SOFTWARE.


Contact Information

    This project is posted at Github, User Name JGLynch54.
