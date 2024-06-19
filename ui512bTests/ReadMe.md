Project Description

	ui512 is a small project to provide basic operations for a variable type of unsigned 512 bit integer.
	The basic operations: zero, copy, compare, add, subtract.
    Other optional modules provide bit ops and multiply / divide.
	It is written in assembly language, using the MASM (ml64) assembler provided as an option within Visual Studio.
	(currently using VS Community 2022 17.9.6)
	It provides external signatures that allow linkage to C and C++ programs,
	where a shell/wrapper could encapsulate the methods as part of an object.
	It has assembly time options directing the use of Intel processor extensions: AVX4, AVX2, SIMD, or none:
	(Z (512), Y (256), or X (128) registers, or regular Q (64bit)).
	If processor extensions are used, the caller must align the variables declared and passed
	on the appropriate byte boundary (e.g. alignas 64 for 512)
	This module is very light-weight (less than 1K bytes) and relatively fast,
	but is not intended for all processor types or all environments. 
	Use for private (hobbyist), or instructional,
	or as an example for more ambitious projects is all it is meant to be.

	ui512b provides basic bit-oriented operations: shift left, shift right, and, or, not,
    least significant bit and most significant bit.

	This sub-project: ui512bTests, is a unit test project that invokes each of the routines in the ui512b assembly. 
	It runs each assembler proc with pseudo-random values. 
	It validates (asserts) expected and returned results.
	It also runs each repeatedly for comparative timings. 
	It provides a means to invoke and debug.
	It illustrates calling the routines from C++.


Installation Instructions

    A.) Set up Visual Studio environment.

	B.) Set up or copy project directories, add as project and or solution to new, blank project under Visual Studio solution explorer.
		Right click test project name, Select properties.
		Navigate to "Linker" in the left panel. Expand it. Select "Input".
		Click on "Additional Dependencies".
		Click on the down arrow button on the right, Select "Edit".
		Add $(SolutionDir)ui512aProject.lib to the dependencies, Click "OK".


Usage Guidelines

	Build the solution.
	Open Test Explorer.
	Expand to see the tests.
	In the upper left corner, Click the Right Green Arrow "Run All Tests"
	Click on each test to see the test results and timings.

	If you wish, you can set break points in either the test code, or the assembler code.
	Select the appropriate test and run test with debug.
	The break will occur.
	You can examine the contents of registers, you can single step, you can look at memory.

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
