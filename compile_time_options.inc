;			compile_time_options
;
;			File:			compile_time_options.inc
;			Author:			John G. Lynch
;			Legal:			Copyright @2024, per MIT License included
;			Date:			August 20, 2025
;
;
IFNDEF							compile_time_options_INC
compile_time_options_INC		EQU			<1>

				INCLUDE			legalnotes.inc

;			Configuration choices
;
;	Note: Choosing these options requires knowledge of the target machine CPU model. If you are unsure of the capabiites of the target machine CPU,
;	You can use the "CPU-Z" tool. https://www.cpuid.com/downloads/cpu-z/cpu-z_2.09-en.exe 
;	Basically, Intel Skylake and later can use "Z", Haswell and later can use BMI2, etc. 
;	Too many processors, options, vendors for me to list here. Go to the CPU vendor specifications, or use the tool to inform your choice.
;
;	Note: This is intended to be a mutually exclusive choice (UseZ thru UseQ).
;	However, the coding of the options selects the "highest" one used and ignores the rest ( If __UseZ ... ELSEIF __UseY ... )

__UseZ			EQU				1									; Use AVX4 processor features (512 bit registers and instructions)
__UseY			EQU				0									; Use AVX2 processor features (256 bit registers and instructions)
__UseX			EQU				0									; Use SIMD/SSE processor features (128 bit registers and instructions)
__UseQ			EQU				0									; Do not use extensions, use standard x64 bit registers and instructions
;
__UseBMI2		EQU				1									; Bit manipulation instructions (Haswell and later) ref:https://en.wikipedia.org/wiki/X86_Bit_manipulation_instruction_set
;
__VerifyRegs	EQU				1									; in debug mode, or with unit tests, define routine to verify non-volatile regs 
__CheckAlign	EQU				0									; User is expected to pass arguments aligned on 64 byte boundaries, 
;																	; This setting enforces that with a check. It should not be necessary, but included to help debugging

ENDIF			; compile_time_options_INC