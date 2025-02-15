# DLC-3 VM

## Description
The Dlang Little Computer 3 virtual machine (VM) was a project to explore the D programming language as well as learn how a VM functions under the hood. This project was based off of the [tutorial](https://www.jmeiners.com/lc3-vm/) written by [Justin Meiners](https://www.jmeiners.com/) & [Ryan Pendleton](https://www.ryanp.me/).

## Lessons Learned
 - How to abstract hardware architectures into a purely software environment. Back in college I had written an assembler for the Simple Instruction Computer (SIC/XE) for a Systems Programmer class, and since then I had wanted to undertake making a virtual machine. While it has taken awhile to finally sit down and do it, it is done.
 - KISS. The largest roadblock I encounter on the project was trying to get fancy with some bit manipulation; however, it was founded on faulty assumptions that required me to reexamine my approach.
 - Remember to unit test. Most of the later bugs I encountered were easily tracked down when I began unit testing each LC-3 instruction.

## Futher Work
While for all intents and purposes I consider this project done, as it was mostly a spike into VMs and writing a project in Dlang, but some things I would like to add in the future are as follows:
 - Complete unit testing for instructions.
 - Better code documentation and cleanup. Ryan & Justin's tutorial also exposed me to the Literate tool and I would like to make use of it, along with cleaning up my vm as well.
 - Refactor the code to not use Dlang's stdc library. Ideally I should be able to achieve the functionality in a more Dlangly fashion, especially if I wish to continue working in the language.

## License
MIT License

Copyright (c) 2025 Harrison Wine

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the “Software”), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
