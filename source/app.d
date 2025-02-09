import std.stdio;

immutable maxMemory = 1 << 16;
immutable pcStart = 0x3000;
enum Registers : ushort
{
	R0 = 0, 
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
enum Opcodes : ushort
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

enum ConditionFlags : ushort
{	
	POS = 1 << 0, /* P */
	ZRO = 1 << 1, /* Z */
	NEG = 1 << 2, /* N */
}

enum TrapCodes : ushort
{
    GETC  = 0x20,  /* get character from keyboard, not echoed onto the terminal */
    OUT   = 0x21,  /* output a character */
    PUTS  = 0x22,  /* output a word string */
    IN    = 0x23,  /* get character from keyboard, echoed onto the terminal */
    PUTSP = 0x24,  /* output a byte string */
    HALT  = 0x25   /* halt the program */
}

enum : ushort
{
    MR_KBSR = 0xFE00, /* keyboard status */
    MR_KBDR = 0xFE02  /* keyboard data */
}

ushort[maxMemory] memory;
ushort[Registers.COUNT] reg;
bool running = true;

int main(string[] args)
{
	args = args[1 .. $];


	//load arguments
	if (args.length < 1)
	{
		writeln("dlc3 [image-file1] ...");
		return 2;
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
	import core.stdc.signal: signal;
	signal(SIGINT, &handle_interrupt);
	disable_input_buffering();

	//Only one condition flag can be set at a given time; initially, set it to the Z flag.
	reg[Registers.COND] = ConditionFlags.ZRO;

	// set the PC to the start position
	reg[Registers.PC] = pcStart;

	while(running)
	{
		// FETCH
		ushort instruction = mem_read(reg[Registers.PC]++);
		ushort opcode = instruction >> 12;
		with (Opcodes) switch (opcode)
		{
			case ADD:
				add_instruction(instruction);
				break;
			case AND:
				and_instruction(instruction);
				break;
			case NOT:
				not_instruction(instruction);
				break;
			case BR:
				br_instruction(instruction);
				break;
			case JMP:
				jmp_instruction(instruction);
				break;
			case JSR:
				jsr_instruction(instruction);
				break;
			case LD:
				ld_instruction(instruction);
				break;
			case LDI:
				ldi_instruction(instruction);
				break;
			case LDR:
				ldr_instruction(instruction);
				break;
			case LEA:
				lea_instruction(instruction);
				break;
			case ST:
				st_instruction(instruction);
				break;
			case STI:
				sti_instruction(instruction);
				break;
			case STR:
				str_instruction(instruction);
				break;
			case TRAP:
				trap_instruction(instruction);
				break;
			case RES: 
			case RTI:
			default:
				return -1;
				break;
		}
	}
	//Shutdown
	restore_input_buffering();
	return 0;
}


void read_image_file(File file)
{
	// origin - location in memory to store image.
	auto origin = file.rawRead(new ushort[1]);
	origin[0] = origin[0].swap16;
	//BUG.hmw - the contents of the file are not ever stored in *p
	ushort max_read = cast(ushort)(maxMemory - origin[0]);
	ushort* p = memory.ptr + origin[0];
	
	foreach (word; file.rawRead(new ushort[max_read]))
	{
		// convert to little endian
		*p++ = swap16(word);
	}

}

ushort swap16(ushort x)
{
	return cast(ushort)((x << 8) | (x >> 8));
} 
unittest
{
	ushort myBits = 0xB000;
	myBits = swap16(myBits);
	assert(myBits == 0xB0);	
}
unittest
{
	ushort myBits = 0x0001;
	myBits = swap16(myBits);
	assert(myBits == 0x0100);	
}

int read_image(string image_path)
{
	auto file = File(image_path, "rb");
	if (file.isOpen)
	{
		read_image_file(file);
		file.close();
		return 1;
	}
	else { return 0; }
}

void mem_write(ushort address, ushort val)
{
	memory[address] = val;
}

ushort mem_read(ushort address)
{
	if (address == MR_KBSR)
	{
		if (check_key())
		{
			memory[MR_KBSR] = (1 << 15);
			memory[MR_KBSR] = cast(ushort)readf("%c");
		}
		else 
		{
			memory[MR_KBSR] = 0;	
		}
	}

	return memory[address];
}

nothrow @nogc void restore_input_buffering()
{
	tcsetattr(STDIN_FILENO, TCSANOW, &original_tio);
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

void ld_instruction(ushort instruction)
{
	ushort dr = (instruction >> 9) & 0x7; 
	ushort pc_offset = extend_sign(instruction & 0x1FF);

	reg[dr] = mem_read(reg[Registers.PC] + pc_offset);
	update_flags(dr);
}

void ldi_instruction(ushort instruction)
{
	ushort dr = (instruction >> 9) & 0x7; 
	ushort pc_offset = extend_sign(instruction & 0x1FF);

	reg[dr] = mem_read(mem_read(reg[Registers.PC] + pc_offset));
	update_flags(dr);
}

void ldr_instruction(ushort instruction)
{
	ushort dr = (instruction >> 9) & 0x7; 
	ushort br = (instruction >> 6) & 0x7;
	ushort pc_offset = extend_sign(instruction & 0x3F);

	reg[dr] = mem_read(br + pc_offset);
	update_flags(dr);
}

void lea_instruction(ushort instruction)
{
	ushort dr = (instruction >> 9) & 0x7; 
	ushort pc_offset = extend_sign(instruction & 0x1FF);

	reg[dr] = cast(ushort)(reg[Registers.PC] + pc_offset);
	update_flags(dr);
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