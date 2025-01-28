import std.stdio;

void main()
{
	immutable maxMemory = 1 << 16;
	immutable pcStart = 0x3000;
	enum Registers 
	{
		R0, 
		R1, 
		R2, 
		R3, 
		R4, 
		R5, 
		R6, 
		R7, 
		PC,
		COND,
		COUNT,
	}
	enum Opcodes 
	{
		BR,     /* branch */
		ADD,    /* add  */
		LD,     /* load */
		ST,     /* store */
		JSR,    /* jump register */
		AND,    /* bitwise and */
		LDR,    /* load register */
		STR,    /* store register */
		RTI,    /* unused */
		NOT,    /* bitwise not */
		LDI,    /* load indirect */
		STI,    /* store indirect */
		JMP,    /* jump */
		RES,    /* reserved (unused) */
		LEA,    /* load effective address */
		TRAP,   /* execute trap */
	}
	enum ConditionFlags
	{	
		POS = 1 << 0, /* P */
		ZRO = 1 << 1, /* Z */
		NEG = 1 << 2, /* N */
	}
	ushort[maxMemory] memory;
	ushort[Registers.COUNT] reg;

	//load arguments
	//setup

	//Only one condition flag can be set at a given time; initially, set it to the Z flag.
	reg[Registers.COND] = ConditionFlags.FL_ZRO;

	// set the PC to the start position
	reg[Registers.PC] = pcStart;

	bool running = true;
	while(running)
	{
		// FETCH
		ushort instruction = mem_read(reg[Registers.PC]++);
		ushort opcode = instruction >> 12;

		switch (opcode)
		{
			case Opcodes.ADD:

				break;
			case Opcodes.AND:

				break;
			case Opcodes.NOT:

				break;
			case Opcodes.BR:

				break;
			case Opcodes.JMP:

				break;
			case Opcodes.JSR:

				break;
			case Opcodes.LD:

				break;
			case Opcodes.LDI:

				break;
			case Opcodes.LDR:

				break;
			case Opcodes.LEA:

				break;
			case Opcodes.ST:

				break;
			case Opcodes.STI:

				break;
			case Opcodes.STR:

				break;
			case Opcodes.TRAP:

				break;
			case Opcodes.RES: 
			case Opcodes.RTI:
			default:
				break;
		}
	}
	//Shutdown
	writeln("Edit source/app.d to start your project.");
}
