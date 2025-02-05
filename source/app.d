import std.stdio;
import std.stdlib;

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

void main(string[] args)
{
	args = args[1 .. $];


	//load arguments
	if (args.length < 1)
	{
		writeln("dlc3 [image-file1] ...");
	}

	foreach (image; args)
	{
		if (!read_image(image))
		{
			writeln("ERROR: failed to load image: ", image);
			return 1;
		}
	}

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
				add_instruction(instruction);
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
/** 
 * 
 * Params:
 *   x = binary val to extend
 *   bit_count = number of bits to extend by
 */
ushort extend_sign(ushort x, int bit_count)
{
	return (x >> (bit_count - 1) & 1) ? (x | (0xFFFF << bit_count)) : x;
}

/** 
 * Any time a value is written to a register the flags need to be updated to indicate sign.
 * Params:
 *   r = register
 */
void update_flags(ushort r)
{
	if (reg[r] == 0)
	{
		reg[Registers.COND] = ConditionFlags.ZRO;
	}
	else if (reg[r] >> 15) //negative value
	{
		reg[Registers.COND] = ConditionFlags.NEG;
	}
	else
	{
		reg[Registers.COND] = ConditionFlags.POS;
	}
}

void add_instruction(ushort instruction)
{
	/// destination register (DR)
	ushort r0 = (instruction >> 9) & 0x1;
	/// first operand (SR1)
	ushort r1 = (instruction >> 6) & 0x7;
	/// immediate mode flag
	ushort imm_flag = ( instruction >> 5) & 0x1;
	
	if (imm_flag)
	{
		ushort imm5 = sign_extend(instruction & 0x1F, 5);
		reg[r0] = reg[r1] + imm5;
	}
	else 
	{
		ushort r2 = instruction & 0x7;
		reg[r0] = reg[r1] + reg[r2];	
	}

	update_flags(r0);
}

void and_instruction(ushort instruction)
{
	/// destination register (DR)
	ushort r0 = (instruction >> 9) & 0x1;
	/// first operand (SR1)
	ushort r1 = (instruction >> 6) & 0x7;
	/// immediate mode flag
	ushort imm_flag = ( instruction >> 5) & 0x1;
	
	if (imm_flag)
	{
		ushort imm5 = extend_sign(instruction & 0x1F);
		r0 = r1 & imm5;
	}
	else
	{
		ushort r2 = instruction & 0x7;
		r0 = r1 & r2;
	}
	update_flags(r0);
}

void br_instruction(ushort instruction)
{	
	ushort cond_flag = (instruction >> 9) & 0x7;

	if (cond_flag & reg[Registers.COND])
	{
		ushort pc_offset = extend_sign(instruction & 0x1FF);
		reg[Registers.PC] += pc_offset;
	}
}

/** 
 * Note - function also handles RET, base_register is '7' in that case.
 */
void jmp_instruction(ushort instruction)
{
	ushort base_register = (instruction >> 6) & 0x7;

	reg[Registers.PC] = reg[base_register];
}

void jsr_instruction(ushort instruction)
{
	// save linkage to calling routine
	reg[7] = reg[Registers.PC];
	if ((instruction >> 11) & 0x1)
	{
		/// JSR
		ushort pc_offset = extend_sign(instruction & 0x7FF);
		reg[Registers.PC] += pc_offset;
	}
	else 
	{
		/// JSRR
		jmp_instruction(instruction);
	}
}


void not_instruction(ushort instruction)
{
	ushort dr = (instruction >> 9) & 0x7; 
	ushort sr = (instruction >> 6) & 0x7;
	
	reg[dr] = cast(ushort)~reg[sr];
	update_flags(dr);
}

void st_instruction(ushort instruction)
{
	ushort sr = (instruction >> 9) & 0x7;
	ushort pc_offset = extend_sign(instruction & 0x1FF);

	mem_write(reg[Registers.PC] + pc_offset, sr);
}

void sti_instruction(ushort instruction)
{
	ushort sr = (instruction >> 9) & 0x7;
	ushort pc_offset = extend_sign(instruction & 0x1FF);

	mem_write(mem_write(reg[Registers.PC] + pc_offset, sr));
}

void str_instruction(ushort instruction)
{
	ushort sr = (instruction >> 9) & 0x7;
	ushort br = (instruction >> 6) & 0x7;
	ushort pc_offset = extend_sign(instruction & 0x1FF);

	mem_write(reg[br] + pc_offset, sr);
}

void trap_instruction(ushort instruction)
{
	ushort trap_vector = instruction & 0x8;
	reg[7] = reg[Registers.PC];
	reg[Registers.PC] = mem_read(trap_vector);
}