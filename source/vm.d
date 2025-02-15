module vm;

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
	BR=0,   /* branch */
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
    MRKBSR = 0xFE00, /* keyboard status */
    MRKBDR = 0xFE02  /* keyboard data */
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
		if (!readImage(image))
		{
			writeln("ERROR: failed to load image: ", image);
			return 1;
		}
	}

	///setup:
	import core.stdc.signal: signal;
	signal(SIGINT, &handleInterrupt);
	disableInputBuffering();

	//Only one condition flag can be set at a given time; initially, set it to the Z flag.
	reg[Registers.COND] = ConditionFlags.ZRO;

	// set the PC to the start position
	reg[Registers.PC] = pcStart;

	while(running)
	{
		///FETCH:
		ushort instruction = memRead(reg[Registers.PC]++);
		ushort opcode = instruction >> 12;

		with (Opcodes) switch (opcode)
		{
			case ADD:
				addInstruction(instruction);
				break;
			case AND:
				andInstruction(instruction);
				break;
			case NOT:
				notInstruction(instruction);
				break;
			case BR:
				brInstruction(instruction);
				break;
			case JMP:
				jmpInstruction(instruction);
				break;
			case JSR:
				jsrInstruction(instruction);
				break;
			case LD:
				ldInstruction(instruction);
				break;
			case LDI:
				ldiInstruction(instruction);
				break;
			case LDR:
				ldrInstruction(instruction);
				break;
			case LEA:
				leaInstruction(instruction);
				break;
			case ST:
				stInstruction(instruction);
				break;
			case STI:
				stiInstruction(instruction);
				break;
			case STR:
				strInstruction(instruction);
				break;
			case TRAP:
				trapInstruction(instruction);
				break;
			case RES: 
			case RTI:
			default:
				return exitVM(-1);
				break;
		}
	}
	//Shutdown
	return exitVM(0);
	
}

int exitVM(int exitCode)
{
	restoreInputBuffering();
	return exitCode;
}

/** 
 * 
 * Params:
 *   file = lc3 obj file
 */
void readImageFile(File file)
{
	// origin - location in memory to store image.
	auto origin = file.rawRead(new ushort[1]);
	origin[0] = origin[0].swap16;
	ushort maxRead = cast(ushort)(maxMemory - origin[0]);
	ushort* p = memory.ptr + origin[0];
	
	foreach (word; file.rawRead(new ushort[maxRead]))
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

int readImage(string imagePath)
{
	auto file = File(imagePath, "rb");
	if (file.isOpen)
	{
		readImageFile(file);
		file.close();
		return 1;
	}
	else { return 0; }
}

void memWrite(ushort address, ushort val)
{
	memory[address] = val;
}

ushort memRead(ushort address)
{
	if (address == MRKBSR)
	{
		if (checkKey())
		{
			memory[MRKBSR] = (1 << 15);
			char tmp;
			readf!" %c"(tmp);
			memory[MRKBDR] = cast(ushort)(tmp);
		}
		else 
		{
			memory[MRKBSR] = 0;	
		}
	}

	return memory[address];
}

import core.sys.posix.termios: termios, TCSANOW, ICANON, ECHO, tcsetattr, tcgetattr;
import core.sys.posix.sys.time: timeval;
import core.sys.posix.sys.select: fd_set, FD_ZERO, FD_SET, SIGINT, select;
import core.sys.posix.unistd: STDIN_FILENO;

termios originalTio;

void disableInputBuffering()
{
	tcgetattr(STDIN_FILENO, &originalTio);
	termios newTio = originalTio;
	newTio.c_lflag &= ~ICANON & ~ECHO;
	tcsetattr(STDIN_FILENO, TCSANOW, &newTio);
}

nothrow @nogc void restoreInputBuffering()
{
	tcsetattr(STDIN_FILENO, TCSANOW, &originalTio);
}

ushort checkKey()
{
	fd_set readfds;
	FD_ZERO(&readfds);
	FD_SET(STDIN_FILENO, &readfds);

	timeval timeout;
	timeout.tv_sec = 0;
	timeout.tv_usec = 0;
	
	return select(1, &readfds, null, null, &timeout) != 0;
}

extern(C) nothrow @nogc void handleInterrupt(int signal) 
{
	restoreInputBuffering();
	return;
}

/** 
 * 
 * Params:
 *   x = binary val to extend
 *   bitCount = number of bits of binary value
 */
ushort signExtend(ushort x, ushort bitCount)
{
	return cast(ushort)(( ( x >> (bitCount-1) ) & 1) ? (x | (0xFFFF << bitCount)) : x);
}

/** 
 * Any time a value is written to a register the flags need to be updated to indicate sign.
 * Params:
 *   r = register
 */
void updateFlags(ushort r)
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

// TODO.hmw - break out instruction functions into their own module
void addInstruction(ushort instruction)
{
	ushort dr = (instruction >> 9) & 0x7;
	ushort sr1 = (instruction >> 6) & 0x7;
	ushort immFlag = ( instruction >> 5) & 0x1;
	
	if (immFlag)
	{
		ushort imm5 = signExtend(instruction & 0x1F, 5);
		reg[dr] = cast(ushort)(reg[sr1] + imm5);
	}
	else 
	{
		ushort sr2 = instruction & 0x7;
		reg[dr] = cast(ushort)(reg[sr1] + reg[sr2]);	
	}
	updateFlags(dr);
}
unittest
{
	reg[Registers.R4] = cast(ushort)2;
	reg[Registers.R3] = cast(ushort)2;
	addInstruction(cast(ushort)0b0001_010_011_0_00_100);
	assert(reg[Registers.R2] == 4);
}
void andInstruction(ushort instruction)
{
	ushort dr = (instruction >> 9) & 0x7;
	ushort sr1 = (instruction >> 6) & 0x7;
	ushort immFlag = ( instruction >> 5) & 0x1;
	
	if (immFlag)
	{
		ushort imm5 = signExtend(instruction & 0x1F, 5);
		reg[dr] = reg[sr1] & imm5;
	}
	else
	{
		ushort sr2 = instruction & 0x7;
		reg[dr] = reg[sr1] & reg[sr2];
	}
	updateFlags(dr);
}
unittest
{
	reg[Registers.R4] = cast(ushort)0b101;
	reg[Registers.R3] = cast(ushort)0b110;
	andInstruction(cast(ushort)0b0101_010_011_0_00_100);
	assert(reg[Registers.R2] == 0b100);
}
unittest
{
	reg[Registers.R3] = cast(ushort)0b101;
	andInstruction(cast(ushort)0b0101_010_011_1_00111);
	assert(reg[Registers.R2] == 0b101);
}

void brInstruction(ushort instruction)
{	
	ushort condFlag = (instruction >> 9) & 0x7;

	if (condFlag & reg[Registers.COND])
	{
		ushort pcOffset = signExtend(instruction & 0x1FF, 9);
		reg[Registers.PC] += pcOffset;
	}
}
unittest
{
	reg[Registers.COND] = ConditionFlags.ZRO;
	reg[Registers.PC] = cast(ushort)1;
	brInstruction(cast(ushort)0b0000_0_0_0_000000001);
	assert(reg[Registers.PC] == 1);
}
unittest
{
	reg[Registers.COND] = ConditionFlags.NEG;
	reg[Registers.PC] = cast(ushort)1;
	brInstruction(cast(ushort)0b0000_1_0_0_000000001);
	assert(reg[Registers.PC] == 2);
}
unittest
{
	reg[Registers.COND] = ConditionFlags.ZRO;
	reg[Registers.PC] = cast(ushort)1;
	brInstruction(cast(ushort)0b0000_1_1_0_000000101);
	assert(reg[Registers.PC] == 6);
}
unittest
{
	reg[Registers.COND] = ConditionFlags.POS;
	reg[Registers.PC] = cast(ushort)1;
	brInstruction(cast(ushort)0b0000_1_1_1_000000001);
	assert(reg[Registers.PC] == 2);
}

/** 
 * Note - function also handles RET, baseRegister is '7' in that case.
 */
void jmpInstruction(ushort instruction)
{
	ushort baseRegister = (instruction >> 6) & 0x7;

	reg[Registers.PC] = reg[baseRegister];
}
unittest
{
	ushort inst = 0b1100_000_010_000000;
	reg[Registers.PC] = cast(ushort)10;
	reg[Registers.R2] = cast(ushort)25;
	jmpInstruction(inst);
	assert(reg[Registers.PC] == 25);
}

void jsrInstruction(ushort instruction)
{
	// save linkage to calling routine
	reg[7] = reg[Registers.PC];
	if ((instruction >> 11) & 0x1)
	{
		/// JSR
		ushort pcOffset = signExtend(instruction & 0x7FF, 11);
		reg[Registers.PC] += pcOffset;
	}
	else 
	{
		/// JSRR
		jmpInstruction(instruction);
	}
}
unittest
{
	//TODO.hmw - add unit test for jsr
}
unittest
{
	//TODO.hmw - add unit test for jsrr
}

void ldInstruction(ushort instruction)
{
	ushort dr = (instruction >> 9) & 0x7; 
	ushort pcOffset = signExtend(instruction & 0x1FF, 9);

	reg[dr] = memRead(cast(ushort)(reg[Registers.PC] + pcOffset));
	updateFlags(dr);
}
unittest
{
	//TODO.hmw - add unit test for ld
}

void ldiInstruction(ushort instruction)
{
	ushort dr = (instruction >> 9) & 0x7; 
	ushort pcOffset = signExtend(instruction & 0x1FF, 9);

	reg[dr] = memRead(memRead(cast(ushort)(reg[Registers.PC] + pcOffset)));
	updateFlags(dr);
}
unittest
{
	//TODO.hmw - add unit test for ldi
}

void ldrInstruction(ushort instruction)
{
	ushort dr = (instruction >> 9) & 0x7; 
	ushort br = (instruction >> 6) & 0x7;
	ushort pcOffset = signExtend(instruction & 0x3F, 6);

	reg[dr] = memRead(cast(ushort)(reg[br] + pcOffset));
	updateFlags(dr);
}
unittest
{
	ushort inst = 0b0110_100_010_000101;
	reg[Registers.R2] = 5;
	memory[10] = 10;
	ldrInstruction(inst);
	assert(reg[Registers.R4] == 10);
}

void leaInstruction(ushort instruction)
{
	ushort dr = (instruction >> 9) & 0x7; 
	ushort pcOffset = signExtend(instruction & 0x1FF, 9);

	reg[dr] = cast(ushort)(reg[Registers.PC] + pcOffset);
	updateFlags(dr);
}
unittest
{
	//TODO.hmw - add unit test for lea
}

void notInstruction(ushort instruction)
{
	ushort dr = (instruction >> 9) & 0x7; 
	ushort sr = (instruction >> 6) & 0x7;
	
	reg[dr] = cast(ushort)~reg[sr];
	updateFlags(dr);
}
unittest
{
	//TODO.hmw - add unit test for not
}

void stInstruction(ushort instruction)
{
	ushort sr = (instruction >> 9) & 0x7;
	ushort pcOffset = signExtend(instruction & 0x1FF, 9);

	memWrite(cast(ushort)(reg[Registers.PC] + pcOffset), reg[sr]);
}
unittest
{
	//TODO.hmw - add unit test for st
}

void stiInstruction(ushort instruction)
{
	ushort sr = (instruction >> 9) & 0x7;
	ushort pcOffset = signExtend(instruction & 0x1FF, 9);

	memWrite(memRead(cast(ushort)(reg[Registers.PC] + pcOffset)), reg[sr]);
}
unittest
{
	//TODO.hmw - add unit test for sti
}

void strInstruction(ushort instruction)
{
	ushort sr = (instruction >> 9) & 0x7;
	ushort br = (instruction >> 6) & 0x7;
	ushort pcOffset = signExtend(instruction & 0x3F, 6);

	memWrite(cast(ushort)(reg[br] + pcOffset), reg[sr]);
}
unittest
{
	//TODO.hmw - add unit test for str
}

// TODO.hmw - break out trap instructions into their own module
// TODO.hmw - develop the trap vectors utilizing dlangs inline asm functionality
void trapInstruction(ushort instruction)
{
	ushort trapVector = instruction & 0xFF;
	reg[7] = reg[Registers.PC];
	with (TrapCodes) final switch (trapVector)
	{
		case GETC:
			/// TRAP GETC
			trapGetc();
			break;
		case OUT:
			/// TRAP OUT
			trapOut();
			break;
		case PUTS:
			/// TRAP PUTS
			trapPuts();
			break;
		case IN:
			/// TRAP IN
			trapIn();
			break;
		case PUTSP:
			/// TRAP PUTSP
			trapPutsp();
			break;
		case HALT:
			/// TRAP HALT
			trapHalt();
			break;
	}
}

void trapGetc()
{
	char tmp;
	readf!" %c"(tmp);
	reg[Registers.R0] = cast(ushort)(tmp);
	updateFlags(Registers.R0);
}

void trapOut()
{
	ushort c = reg[Registers.R0] & 0xFF;
	stdout.write(cast(char)c);
	stdout.flush();
}

void trapPuts()
{
	ushort* c = memory.ptr + reg[Registers.R0];
	while(*c) { stdout.write(cast(char)*c++); }
	stdout.flush();
}

void trapIn()
{
	stdout.write("Enter a character: ");
	trapGetc();
	stdout.flush();
}

void trapPutsp()
{
	ushort* c = memory.ptr + reg[Registers.R0];
	while(*c)
	{ 
		char c1 = cast(char)*c & 0xFF;
		stdout.write(c1); 
		char c2 = cast(char)*c >> 8;
		if (c2) { stdout.write(c2); }
		c++;
	}
	stdout.flush();
}

void trapHalt()
{
	running = false;
	writeln("HALT");
	stdout.flush();
}