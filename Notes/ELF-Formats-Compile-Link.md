#ELF格式解析#

ELF作为Linux系统下的可执行文件与动态库的格式，一直没有完全明白，其中一个原因是ELF格式的很多教程参考ELF官方文档，讲解过程将目标文件(.o)和ELF文件格式混起来讲解，最终导致混乱，两个都没能清晰说明白。再者，很多教程也没有结合实例进行讲解，对`.o`，`a.out`和`.so`文件进行区分对比，导致很多概念混淆。

这一篇文章想从编译链接开始，首先总结编译中涉及到ELF格式的一些知识，然后将编译的结果`.o`文件进行分析说明；再总结链接中关于ELF格式的一些知识，最后将ELF文件和`.so`文件进行分析说明。希望最终通过这篇文章的总结，能够对编译链接过程有一个简单认识，更重要的是能够理解ELF文件的内容。

文章里面会列举很多完整的代码与解析结果，这会导致文章很长，这部分只分析到ELF可执行文件格式，至于动态库的格式后面再另外一篇续中继续解析。

我们以如下的代码为例，对整篇文章中涉及的文件进行编译生成。

```
// hello.c
#include <stdio.h>
#include "output.h"

int global_init_var = 1;
int global_uninit_var;

int main()
{
	static int static_var = 3;
	static int static_var2;

	printf("Before call Func.\n");
	
	output("Hello World", global_init_var + static_var);

	static_var2 = 4;
	printf("After call Func. static_var2: %d\n", static_var2);

	return 0;
}

// output.h
#pragma once

int output(const char * str, int val);

// output.c
#include "output.h"
#include <stdio.h>

extern int global_uninit_var;

int output(const char * str, int val)
{
	if (0 == str)
	{
		return -1;
	}
	
	printf("%s: %s-%d", __func__, str, val);

	global_uninit_var = 2;
	printf("global_uninit_var: %d\n", global_uninit_var);

	return 0;
}
```

###可执行文件编译###

从源码到最终的可执行文件经过两个过程：编译和链接。这一节主要说编译中的一些知识总结。

编译过程又可以细分为预处理，编译，汇编三个子过程。预处理主要是将头文件，宏定义，条件编译等进行处理，将头文件爱包含到`.c`文件中，将宏定义进行替换等，可以使用`gcc -E hello.c -o hello.i`对C语言源代码进行预处理，预处理结果是一个可读的`.i`文本文件。编译主要是将预处理后的文件进行编译，生成汇编代码，可以使用`gcc -S hello.i -o hello.s`对预处理的文件进行编译，编译后的文件是`.s`汇编文件，它也是可读的文本文件。最后一步是汇编，即将汇编文件转换为二进制文件，即下一节中要分析的目标文件。汇编可以通过`gcc`进行，也可以使用汇编程序`as`来完成，`as hello.s -o hello.o`或`gcc -c hello.s -o hello.o`。

其实从上面的三个过程中可以看出，预处理就是对源代码的处理，它不会对编译生成的目标文件产生影响。对编译生成目标文件有影响的就是后面的两个过程，编译和汇编。

编译可以再次进行细分，即源码的词法分析，语法分析，语义分析，中间语言生成，目标代码生成。以中间语言为界限，编译器又被分为了编译前端和编译后端。编译前端完成中间语言生成，中间语言是与机器无关的跨平台代码；编译后端则将中间代码转换为目标机器代码，对于我们这里的例子来讲即生成i386兼容的汇编代码。

编译后端主要包括了代码生成器和目标代码优化器。代码生成器将中间代码转换为目标机器代码，这个过程直接依赖于目标机器，不同的机器有不同的字长，寄存器和整数类型。其实这块就和最终的目标文件有关系了，比如对于X86的平台，汇编中变量地址长度为4字节；而X64的平台上指针类型为8字节长。目标代码优化也和目标平台紧密相关，对最终生成的代码长度有直接影响。

用如下的命令，可以直接一步将代码编译为汇编代码。

```
$ gcc -S -m32 hello.c -o hello.s
$ gcc -S -m32 output.c -o output.s
```

其实到汇编代码这一级，生成了目标平台代码，我们已经能看到最终要放到目标文件中的一些数据了，如下为`hello.c`编译为汇编代码文件后的`hello.s`的内容。

```
	.file	"hello.c"
	.globl	global_init_var
	.data
	.align 4
	.type	global_init_var, @object
	.size	global_init_var, 4
global_init_var:
	.long	1
	.comm	global_uninit_var,4,4
	.section	.rodata
.LC0:
	.string	"Before call Func."
.LC1:
	.string	"Hello World"
	.align 4
.LC2:
	.string	"After call Func. static_var2: %d\n"
	.text
	.globl	main
	.type	main, @function
main:
.LFB0:
	.cfi_startproc
	leal	4(%esp), %ecx
	.cfi_def_cfa 1, 0
	andl	$-16, %esp
	pushl	-4(%ecx)
	pushl	%ebp
	.cfi_escape 0x10,0x5,0x2,0x75,0
	movl	%esp, %ebp
	pushl	%ecx
	.cfi_escape 0xf,0x3,0x75,0x7c,0x6
	subl	$4, %esp
	subl	$12, %esp
	pushl	$.LC0
	call	puts
	addl	$16, %esp
	movl	global_init_var, %edx
	movl	static_var.1938, %eax
	addl	%edx, %eax
	subl	$8, %esp
	pushl	%eax
	pushl	$.LC1
	call	output
	addl	$16, %esp
	movl	$4, static_var2.1939
	movl	static_var2.1939, %eax
	subl	$8, %esp
	pushl	%eax
	pushl	$.LC2
	call	printf
	addl	$16, %esp
	movl	$0, %eax
	movl	-4(%ebp), %ecx
	.cfi_def_cfa 1, 0
	leave
	.cfi_restore 5
	leal	-4(%ecx), %esp
	.cfi_def_cfa 4, 4
	ret
	.cfi_endproc
.LFE0:
	.size	main, .-main
	.data
	.align 4
	.type	static_var.1938, @object
	.size	static_var.1938, 4
static_var.1938:
	.long	3
	.local	static_var2.1939
	.comm	static_var2.1939,4,4
	.ident	"GCC: (Ubuntu 5.4.0-6ubuntu1~16.04.10) 5.4.0 20160609"
	.section	.note.GNU-stack,"",@progbits
```

可见此时对于函数和变量的引用都是使用符号，比如`main()`函数中调用`output()`函数，对其引用仍然是`call output`。

再经过汇编器完成代码的汇编之后，就变成了目标文件(`.o`)。目标文件中保存了二进制的代码，这块是下一节要分析的内容。使用如下命令，分别将两个`.s`文件汇编为对应的目标文件。

```
$ as --32 hello.s -o hello.o
$ as --32 output.s -o output.o
```

这里可能会有一个问题，既然代码最终要形成一个文件，为何要分开编译这么多`.o`呢？其实这是一个解决问题的思路，如果将所有代码放到一起，直接编译出一个可执行的文件，也不是不可以，但是存在问题是，如果项目足够大，单纯C代码就要几百兆，甚至是几个G，那么代码维护相当困难；其次，编译时因为他们在一个文件中，那么整个文件都要编译，编译时间与代价可想而知。之所以分割那么多`.c`，一方面是将问题分块，分而治之；另外一方面，在编译中如果只修改了部分代码，就可以单独只针对这块代码进行编译，其他已经编译好的`.o`文件可以直接参与链接，节省时间。

> 注： 编译程序，将整个编译过程打印出来可以使用这个命令，`gcc -v -m32 -g hello.c output.c`。X64系统上编译的X86的程序，所以要加入`-m32`。

###目标文件格式###

上一节中介绍到编译过程中生成的目标文件，我们这个例子中即`hello.o`和`output.o`。

编译器编译源代码后生成的文件叫做目标文件，它已经是二进制文件了，即"可执行文件"。由于它们没有经过链接，其中的跨模块的符号引用都是假设值，直接执行肯定会出现错误。尽管如此，目标文件本身其实就是按照可执行文件格式存储的，和真正可以执行的可执行文件在结构上略有差异。

PC上流行的可执行文件主要有Windows下的PE（Portable Executable）和Linux上的ELF（Executable Linkable Format），它们都是`COFF`的变种。目标文件就是源码编译后未链接的中间文件，即Windows上的`.obj`和Linux上的`.o`，上面说了它们和各自对应的可执行文件内容和结构很相似。Windows上统称`PE-COFF`文件格式，Linux上统称`ELF`。动态链接库也都按照可执行文件格式存储，即Windows上的`DLL(Dynamic Linking Library)`和Linux上的`SO`库。

目标文件中的内容其实从上面汇编中也大概可以看出来，包括指令，数据，除此之外还需要符号表，调试信息，字符串等链接中所需信息。目标文件将这些信息按照不同的属性进行分类，然后将它们存储到不同的节或段中。一个简单的目标文件格式(以ELF为例)如下：

|   ELF Header  |
|---------------|
| .text section |
| .data section |
| .bss section  |

ELF文件的开始处为`文件头`，它描述整个文件的文件属性，包括文件类型，是否可执行，静态链接还是动态链接，入口地址，目标硬件，目标操作系统等。此外它还应该包括一个段表，用于描述后面的各个`Section`，比如段的偏移，长度等。`.text`段则主要保存代码，`.data`段则保存有初始值的全局变量和局部静态变量等，`.bss`则用于保存未初始化的全局变量和局部静态变量。这是最简化的格式示意图，真正的结构要更复杂一些，下面就以`hello.o`为例逐块解析一下文件内容（32位平台上的文件为例）。

ELF格式最开始一部分是文件头，它的C语言格式结构体格式如下：

```
#define EI_NIDENT	16

typedef struct elf32_hdr{
  unsigned char	e_ident[EI_NIDENT];	// 如下结构体
  Elf32_Half	e_type;		// ELF文件类型
  Elf32_Half	e_machine;	// 1 为重定位，2为可执行文件，3为动态链接库，4为CoreDump等
  Elf32_Word	e_version;	// CPU类型，3为 EM_386，即IntelX86 CPU
  Elf32_Addr	e_entry;  	// 可执行程序入口点
  Elf32_Off	 e_phoff;		// 程序头偏移 Program headers
  Elf32_Off	 e_shoff;		// 节表头偏移 Section headers
  Elf32_Word	e_flags;	// ELF标志位，用来标识ELF平台相关属性
  Elf32_Half	e_ehsize;	// ELF文件头大小，例子为52字节
  Elf32_Half	e_phentsize;// 程序头大小
  Elf32_Half	e_phnum;	// 程序头的个数
  Elf32_Half	e_shentsize;// 节头大小
  Elf32_Half	e_shnum;	// 节头数量
  Elf32_Half	e_shstrndx;	// 段表字符串表所在段 在段表中的下标
} Elf32_Ehdr;

// IDENT部分也可以按照如下格式进行格式化，易于理解
typedef struct elf32_eIdent{
  unsigned char e_magic[4];		// 固定的 7F 45 4C 46，即7F-“ELF”
  unsigned char e_class;		// 文件类型，1 ELF32，2 ELF64
  unsigned char e_endian;		// 文件字节序，1 LSB，2 MSB
  unsigned char e_version;		// 版本号，目前必须设置为EV_CURRENT，即为1
  unsigned char e_osapi;		// 默认为0，即UNIX-System V
  unsigned char e_pad[8];		// 未使用字节，设置为0
}Elf32_EIndet;
```

用`readelf -h`将`hello.o`的ELF头读取出来如下：

```
$ readelf -h hello.o
ELF 头：
  Magic：   7f 45 4c 46 01 01 01 00 00 00 00 00 00 00 00 00
  类别:                              ELF32
  数据:                              2 补码，小端序 (little endian)
  版本:                              1 (current)
  OS/ABI:                            UNIX - System V
  ABI 版本:                          0

  类型:                              REL (可重定位文件)
  系统架构:                          Intel 80386
  版本:                              0x1
  入口点地址：               			0x0
  程序头起点：          				0 (bytes into file)
  Start of section headers:         912 (bytes into file)
  标志：             				  0x0
  本头的大小：       					52 (字节)
  程序头大小：       					0 (字节)
  Number of program headers:        0
  节头大小：         				 40 (字节)
  节头数量：         				 13
  字符串表索引节头： 10
```

按照`Elf32_Ehdr`结构体内容可以进行简单的对照查看。

```
$ hexdump -C -n 52 hello.o
00000000  7f 45 4c 46 01 01 01 00  00 00 00 00 00 00 00 00  |.ELF............|
00000010  01 00 03 00 01 00 00 00  00 00 00 00 00 00 00 00  |................|
00000020  90 03 00 00 00 00 00 00  34 00 00 00 00 00 28 00  |........4.....(.|
00000030  0d 00 0a 00                                       |....|
```

从上面的十六进制可以看出，在第十七个字节开始处，即`e_type`字段的值为`0x0001`，即表示重定位文件类型；同样在第31个字节处为字段`e_shoff`开始字节，表示节头从文件的`0x00000390`字节开始，与上面通过`readelf`获得的结果一样。其他的内容可以参考`elf.h`头文件中定义的各字段的值进行对比查看。

这里要说的是对于重定位文件来说，即这里的目标文件`.o`，它们并不是用来执行的，所以它们头中的程序头偏移值以及程序头大小，程序头的个数等字段均为0。其实这里就引出了ELF格式的两个视图的概念，即链接视图和执行视图。由于目标文件（`.o`）其实仅用于程序构建中的链接，不会进入内存执行，所以它不会存在执行视图中的内容。但是这里要注意一个问题，对于可执行的程序来说，它里面是包含两个视图的，它的链接视图当然不是为了链接（动态链接库用于链接除外），它是为了进行冲定位等操作。所以对于目标文件来说，这里只需要对其链接视图进行分析即可（执行试图在后面分析可执行文件时会进行分析）。

在链接视图中，除了ELF头之外，文件剩余部分都是由节头表（多个节头组成的一块内容）的内容进行安排。不过正常情况下，目标文件中ELF头后为代码节。下面先看一下打印出来各个节头。

```
$ readelf -S hello.o
共有 13 个节头，从偏移量 0x390 开始：

节头：
  [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al
  [ 0]                   NULL            00000000 000000 000000 00      0   0  0
  [ 1] .text             PROGBITS        00000000 000034 00006c 00  AX  0   0  1
  [ 2] .rel.text         REL             00000000 0002d8 000050 08   I 11   1  4
  [ 3] .data             PROGBITS        00000000 0000a0 000008 00  WA  0   0  4
  [ 4] .bss              NOBITS          00000000 0000a8 000004 00  WA  0   0  4
  [ 5] .rodata           PROGBITS        00000000 0000a8 000042 00   A  0   0  4
  [ 6] .comment          PROGBITS        00000000 0000ea 000036 01  MS  0   0  1
  [ 7] .note.GNU-stack   PROGBITS        00000000 000120 000000 00      0   0  1
  [ 8] .eh_frame         PROGBITS        00000000 000120 000044 00   A  0   0  4
  [ 9] .rel.eh_frame     REL             00000000 000328 000008 08   I 11   8  4
  [10] .shstrtab         STRTAB          00000000 000330 00005f 00      0   0  1
  [11] .symtab           SYMTAB          00000000 000164 000110 10     12  11  4
  [12] .strtab           STRTAB          00000000 000274 000064 00      0   0  1
Key to Flags:
  W (write), A (alloc), X (execute), M (merge), S (strings)
  I (info), L (link order), G (group), T (TLS), E (exclude), x (unknown)
  O (extra OS processing required) o (OS specific), p (processor specific)
```

节头从上面的ELF头中可以发现，节头从文件第912字节偏移处开始，一共十三个节头，每个节头40个字节。上面给出了易读的节表。如下为节头的C语言结构，

```
typedef struct elf32_shdr {
  Elf32_Word	sh_name;	// 节名字在字符串表中索引值，`.shstrtab`的字符串表
  Elf32_Word	sh_type;	// 节类型，比如符号节，重定位节，字符表节，动态链接符号表等
  Elf32_Word	sh_flags;	// 节的标记值，进程空间中属性，可写，分配空间，可执行等
  Elf32_Addr	sh_addr;	// 节虚拟地址，如果节被加载，表示内存中虚拟地址，否则为0
  Elf32_Off	sh_offset;	// 节在文件中的偏移
  Elf32_Word	sh_size;	// 节内容的长度
  Elf32_Word	sh_link;	// 节链接信息，即对应符号和
  Elf32_Word	sh_info;	// 
  Elf32_Word	sh_addralign;	// 节地址对齐，单位为`2^sh_addralign`字节
  Elf32_Word	sh_entsize;	// 包含固定大小项的节，比如符号表，表示一项的大小
} Elf32_Shdr;
```

如下列举部分系统保留段，及其它们的属性。

| Name | sh_type | sh_flag|
|------|---------|--------|
|.bss  |SHT_NOBITS| SHF_ALLOC + SHF_WRITE |
|.commont  |SHT_PROGBITS | none |
|.data  |SHT_PROGBITS | SHF_ALLOC + SHF_WRITE |
|.data1  |SHT_PROGBITS| SHF_ALLOC + SHF_WRITE |
|.debug  |SHT_PROGBITS| none |
|.dynamic|SHT_DYNAMIC| SHF_ALLOC + SHF_WRITE |
|.hash  |SHT_HASH | SHF_ALLOC |
|.line  |SHT_PROGBITS| none |
|.note  |SHT_NOTE | none |
|.rodata |SHT_PROGBITS | SHF_ALLOC |
|.rodata1|SHT_PROGBITS | SHF_ALLOC |
|.shstrtab|SHT_STRTAB| none |
|.strtab  |SHT_STRTAB| SHF_ALLOC |
|.symtab  |SHT_SYMTAB| 同字符串表 |
|.text  |SHT_PROGBITS| SHF_ALLOC + SHF_WRITE |

其中节的链接信息（`sh_link`和`sh_info`）是与节类型相关的，只有链接相关的节，两个字段才有意义。

| sh_type | sh_link |      sh_info      |
|---------|---------|-------------------|
|SHT_DYNAMIC| 该段所使用的字符串表在节表中下标| 0 |
|SHT_HASH | 该段所使用的符号表在节表中下标| 0 |
|SHT_REL | 该段所使用相应符号表在节表中下标|该重定位表所作用的节在节表中下标|
|SHT_RELA | 该段所使用相应符号表在节表中下标|该重定位表所作用的节在节表中下标|
|SHT_SYMTAB | 操作系统相关的 | 操作系统相关的 |
|SHT_DYNSYM | 操作系统相关的 | 操作系统相关的 |
|other | SHN_UNDEF | 0|

所有节头的十六进制数据如下所示，第一个节头为空，后面节头每四十字节为一个，与C语言结构体可以对照查看。

```
00000390  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
000003b0  00 00 00 00 00 00 00 00  1f 00 00 00 01 00 00 00  |................|
000003c0  06 00 00 00 00 00 00 00  34 00 00 00 6c 00 00 00  |........4...l...|
000003d0  00 00 00 00 00 00 00 00  01 00 00 00 00 00 00 00  |................|
000003e0  1b 00 00 00 09 00 00 00  40 00 00 00 00 00 00 00  |........@.......|
000003f0  d8 02 00 00 50 00 00 00  0b 00 00 00 01 00 00 00  |....P...........|
00000400  04 00 00 00 08 00 00 00  25 00 00 00 01 00 00 00  |........%.......|
00000410  03 00 00 00 00 00 00 00  a0 00 00 00 08 00 00 00  |................|
00000420  00 00 00 00 00 00 00 00  04 00 00 00 00 00 00 00  |................|
00000430  2b 00 00 00 08 00 00 00  03 00 00 00 00 00 00 00  |+...............|
00000440  a8 00 00 00 04 00 00 00  00 00 00 00 00 00 00 00  |................|
00000450  04 00 00 00 00 00 00 00  30 00 00 00 01 00 00 00  |........0.......|
00000460  02 00 00 00 00 00 00 00  a8 00 00 00 42 00 00 00  |............B...|
00000470  00 00 00 00 00 00 00 00  04 00 00 00 00 00 00 00  |................|
00000480  38 00 00 00 01 00 00 00  30 00 00 00 00 00 00 00  |8.......0.......|
00000490  ea 00 00 00 36 00 00 00  00 00 00 00 00 00 00 00  |....6...........|
000004a0  01 00 00 00 01 00 00 00  41 00 00 00 01 00 00 00  |........A.......|
000004b0  00 00 00 00 00 00 00 00  20 01 00 00 00 00 00 00  |........ .......|
000004c0  00 00 00 00 00 00 00 00  01 00 00 00 00 00 00 00  |................|
000004d0  55 00 00 00 01 00 00 00  02 00 00 00 00 00 00 00  |U...............|
000004e0  20 01 00 00 44 00 00 00  00 00 00 00 00 00 00 00  | ...D...........|
000004f0  04 00 00 00 00 00 00 00  51 00 00 00 09 00 00 00  |........Q.......|
00000500  40 00 00 00 00 00 00 00  28 03 00 00 08 00 00 00  |@.......(.......|
00000510  0b 00 00 00 08 00 00 00  04 00 00 00 08 00 00 00  |................|
00000520  11 00 00 00 03 00 00 00  00 00 00 00 00 00 00 00  |................|
00000530  30 03 00 00 5f 00 00 00  00 00 00 00 00 00 00 00  |0..._...........|
00000540  01 00 00 00 00 00 00 00  01 00 00 00 02 00 00 00  |................|
00000550  00 00 00 00 00 00 00 00  64 01 00 00 10 01 00 00  |........d.......|
00000560  0c 00 00 00 0b 00 00 00  04 00 00 00 10 00 00 00  |................|
00000570  09 00 00 00 03 00 00 00  00 00 00 00 00 00 00 00  |................|
00000580  74 02 00 00 64 00 00 00  00 00 00 00 00 00 00 00  |t...d...........|
00000590  01 00 00 00 00 00 00 00                           |........|
```

从上面十六进制要完全对照出`readelf`的输出，目前还不太现实，还有一部分节没有解释它的内容，解释后就能完全解析出来。

根据上面各个节的偏移和大小，可以大致看出整个`hello.o`的组成。里面部分节的内容是叠加的，其实并非是这样，这里面`.bss`节本身在文件中是不占内容的，`.note.GNU-stack`在目标文件中也不占内容。

```
ELF Header         000000 000034
.text 		   000034 00006c
.data              0000a0 000008
//.bss             0000a8 000004
.rodata            0000a8 000042
.comment           0000ea 000036
//.note.GNU-stack  000120 000000
.eh_frame          000120 000044
.symtab            000164 000110
.strtab            000274 000064
.rel.text 	   0002d8 000050
.rel.eh_frame      000328 000008
.shstrtab          000330 00005f
.pad               00038f 000001
sec table          000390 000208 
```

根据整个文件中各个节的顺序依次解析，在ELF头后就是代码节，使用`objdump -s`输出`hello.o`中的代码节内容。

```
$ objdump -d hello.o 

hello.o：     文件格式 elf32-i386

Contents of section .text:
 0000 8d4c2404 83e4f0ff 71fc5589 e55183ec  .L$.....q.U..Q..
 0010 0483ec0c 68000000 00e8fcff ffff83c4  ....h...........
 0020 108b1500 000000a1 04000000 01d083ec  ................
 0030 08506812 000000e8 fcffffff 83c410c7  .Ph.............
 0040 05000000 00040000 00a10000 000083ec  ................
 0050 08506820 000000e8 fcffffff 83c410b8  .Ph ............
 0060 00000000 8b4dfcc9 8d61fcc3           .....M...a.. 

Disassembly of section .text:
00000000 <main>:
   0:	8d 4c 24 04          	lea    0x4(%esp),%ecx
   4:	83 e4 f0             	and    $0xfffffff0,%esp
   7:	ff 71 fc             	pushl  -0x4(%ecx)
   a:	55                   	push   %ebp
   b:	89 e5                	mov    %esp,%ebp
   d:	51                   	push   %ecx
   e:	83 ec 04             	sub    $0x4,%esp
  11:	83 ec 0c             	sub    $0xc,%esp
  14:	68 00 00 00 00       	push   $0x0
  19:	e8 fc ff ff ff       	call   1a <main+0x1a>
  1e:	83 c4 10             	add    $0x10,%esp
  21:	8b 15 00 00 00 00    	mov    0x0,%edx
  27:	a1 04 00 00 00       	mov    0x4,%eax
  2c:	01 d0                	add    %edx,%eax
  2e:	83 ec 08             	sub    $0x8,%esp
  31:	50                   	push   %eax
  32:	68 12 00 00 00       	push   $0x12
  37:	e8 fc ff ff ff       	call   38 <main+0x38>
  3c:	83 c4 10             	add    $0x10,%esp
  3f:	c7 05 00 00 00 00 04 	movl   $0x4,0x0
  46:	00 00 00 
  49:	a1 00 00 00 00       	mov    0x0,%eax
  4e:	83 ec 08             	sub    $0x8,%esp
  51:	50                   	push   %eax
  52:	68 20 00 00 00       	push   $0x20
  57:	e8 fc ff ff ff       	call   58 <main+0x58>
  5c:	83 c4 10             	add    $0x10,%esp
  5f:	b8 00 00 00 00       	mov    $0x0,%eax
  64:	8b 4d fc             	mov    -0x4(%ebp),%ecx
  67:	c9                   	leave  
  68:	8d 61 fc             	lea    -0x4(%ecx),%esp
  6b:	c3                   	ret 
```

从反汇编的代码中可以看到整个代码段的基地址为`0x00000000`，其中涉及的函数调用都用的相对地址，这个地址会在后面链接中进行重定位或重置，后面涉及到了再详细分析。代码节的内容长度为`0x6c`，反汇编长度即为`0x6c`，所以代码节没有其他的数据，全部是代码。

代码后为`.data`节，其中包含了初始化的全局变量和静态局部变量等。使用`objdump -s`打印出数据节的内容，如下所示。其中仅包含两个初始值为1和3的四字节长变量，它们其实就是源码中`int global_init_var = 1;`和`static int static_var = 3;`两个变量。

```
Contents of section .data:
 0000 01000000 03000000                    ........
```

`.bss`节前面说过它是保存未初始化局部静态变量和未初始化全局变量用，它在文件中不占用空间。如果在可执行文件中，加载到内存时则必须为其分配指定长度的内存空间。

`.rodata`节为只读数据节，它主要包括字符串常量，全局const变量等。`.rodata1`和该节包含内容类似。如果在可执行文件中，它的内容加载到内存之后不可写与执行，只能读取。同样用`objdump -s`查看该节内容，如下代码段所示。可以看到其中包含了程序中的常量，本程序中主要是要打印的格式字符串。

```
Contents of section .rodata:
 0000 4265666f 72652063 616c6c20 46756e63  Before call Func
 0010 2e004865 6c6c6f20 576f726c 64000000  ..Hello World...
 0020 41667465 72206361 6c6c2046 756e632e  After call Func.
 0030 20737461 7469635f 76617232 3a202564   static_var2: %d
 0040 0a00                                 ..
```

`.comment`节为注释信息节，保存说明信息，主要是编译器的版本信息。比如如下`objdump -s hello.o`打印出来的该节内容。从内容可以看到，里面主要包含了该文件由那个系统上的什么版本编译器编译。

```
Contents of section .comment:
 0000 00474343 3a202855 62756e74 7520352e  .GCC: (Ubuntu 5.
 0010 342e302d 36756275 6e747531 7e31362e  4.0-6ubuntu1~16.
 0020 30342e31 30292035 2e342e30 20323031  04.10) 5.4.0 201
 0030 36303630 3900                        60609.  
```

`.note.GNU-stack`节为堆栈提示节，它其实是一个空的节，不包含任何数据，节数据长度为0。那么该节做什么用的呢？它只是一个提示信息，如果目标文件中存在该节，告诉连接器`ld`它不需要可执行的栈。当然，正常的模块都不需要可执行的栈存在，而对于栈溢出攻击很多时候都需要栈具有可执行属性。所以设置一个该节，告诉连接器它不需要可执行栈；同样使用在汇编代码时使用`--noexecstack`选项也可以达到同样目的。这个功能只在`GCC`中生效。

`.eh_frame`为异常处理相关的节，这个是一个比较大的话题，这里不展开。使用`readelf -Wwf`命令可以读取文件中该节内容，如下。它的内容由一个`CIE(Commmon Information Entry)`结构体和多个`FDE(Frame Description Entry)`组成。

```
$ readelf -Wwf hello.o
Contents of the .eh_frame section:

00000000 00000014 00000000 CIE
  Version:               1
  Augmentation:          "zR"
  Code alignment factor: 1
  Data alignment factor: -4
  Return address column: 8
  Augmentation data:     1b

  DW_CFA_def_cfa: r4 (esp) ofs 4
  DW_CFA_offset: r8 (eip) at cfa-4
  DW_CFA_nop
  DW_CFA_nop

00000018 00000028 0000001c FDE cie=00000000 pc=00000000..0000006c
  DW_CFA_advance_loc: 4 to 00000004
  DW_CFA_def_cfa: r1 (ecx) ofs 0
  DW_CFA_advance_loc: 7 to 0000000b
  DW_CFA_expression: r5 (ebp) (DW_OP_breg5 (ebp): 0)
  DW_CFA_advance_loc: 3 to 0000000e
  DW_CFA_def_cfa_expression (DW_OP_breg5 (ebp): -4; DW_OP_deref)
  DW_CFA_advance_loc1: 89 to 00000067
  DW_CFA_def_cfa: r1 (ecx) ofs 0
  DW_CFA_advance_loc: 1 to 00000068
  DW_CFA_restore: r5 (ebp)
  DW_CFA_advance_loc: 3 to 0000006b
  DW_CFA_def_cfa: r4 (esp) ofs 4
```

`.symtab`节为符号节，其中包含了程序的符号信息。它其中每一项都为一个固定结构，C结构体格式如下代码块。

```
typedef struct elf32_sym{
  Elf32_Word	st_name;    // 名字在字符串表索引
  Elf32_Addr	st_value;   // 符号对应的值，和符号有关，可能为绝对地址，也可能为地址值
  Elf32_Word	st_size;    // 符号大小
  unsigned char	st_info;    // 符号类型和绑定信息
  unsigned char	st_other;   // 保留值，未使用
  Elf32_Half	st_shndx;   // 符号所在节
} Elf32_Sym;
```

```
$ readelf -s hello.o

Symbol table '.symtab' contains 17 entries:
   Num:    Value  Size Type    Bind   Vis      Ndx Name
     0: 00000000     0 NOTYPE  LOCAL  DEFAULT  UND 
     1: 00000000     0 FILE    LOCAL  DEFAULT  ABS hello.c
     2: 00000000     0 SECTION LOCAL  DEFAULT    1 
     3: 00000000     0 SECTION LOCAL  DEFAULT    3 
     4: 00000000     0 SECTION LOCAL  DEFAULT    4 
     5: 00000000     0 SECTION LOCAL  DEFAULT    5 
     6: 00000004     4 OBJECT  LOCAL  DEFAULT    3 static_var.1938
     7: 00000000     4 OBJECT  LOCAL  DEFAULT    4 static_var2.1939
     8: 00000000     0 SECTION LOCAL  DEFAULT    7 
     9: 00000000     0 SECTION LOCAL  DEFAULT    8 
    10: 00000000     0 SECTION LOCAL  DEFAULT    6 
    11: 00000000     4 OBJECT  GLOBAL DEFAULT    3 global_init_var
    12: 00000004     4 OBJECT  GLOBAL DEFAULT  COM global_uninit_var
    13: 00000000   108 FUNC    GLOBAL DEFAULT    1 main
    14: 00000000     0 NOTYPE  GLOBAL DEFAULT  UND puts
    15: 00000000     0 NOTYPE  GLOBAL DEFAULT  UND output
    16: 00000000     0 NOTYPE  GLOBAL DEFAULT  UND printf
```

使用`hexdump`命令列举符号节的十六进制内容如下所示：

```
$ hexdump -C -s 356 -n 272 hello.o
00000164  00 00 00 00 00 00 00 00  00 00 00 00 00 00 00 00  |................|
00000174  01 00 00 00 00 00 00 00  00 00 00 00 04 00 f1 ff  |................|
00000184  00 00 00 00 00 00 00 00  00 00 00 00 03 00 01 00  |................|
00000194  00 00 00 00 00 00 00 00  00 00 00 00 03 00 03 00  |................|
000001a4  00 00 00 00 00 00 00 00  00 00 00 00 03 00 04 00  |................|
000001b4  00 00 00 00 00 00 00 00  00 00 00 00 03 00 05 00  |................|
000001c4  09 00 00 00 04 00 00 00  04 00 00 00 01 00 03 00  |................|
000001d4  19 00 00 00 00 00 00 00  04 00 00 00 01 00 04 00  |................|
000001e4  00 00 00 00 00 00 00 00  00 00 00 00 03 00 07 00  |................|
000001f4  00 00 00 00 00 00 00 00  00 00 00 00 03 00 08 00  |................|
00000204  00 00 00 00 00 00 00 00  00 00 00 00 03 00 06 00  |................|
00000214  2a 00 00 00 00 00 00 00  04 00 00 00 11 00 03 00  |*...............|
00000224  3a 00 00 00 04 00 00 00  04 00 00 00 11 00 f2 ff  |:...............|
00000234  4c 00 00 00 00 00 00 00  6c 00 00 00 12 00 01 00  |L.......l.......|
00000244  51 00 00 00 00 00 00 00  00 00 00 00 10 00 00 00  |Q...............|
00000254  56 00 00 00 00 00 00 00  00 00 00 00 10 00 00 00  |V...............|
00000264  5d 00 00 00 00 00 00 00  00 00 00 00 10 00 00 00  |]...............|
```

从上述列举出的内容可以看出，与节头表类似，第一项都为空。每一项为结构体`Elf32_Sym`，它的大小正好为16字节。将十六进制和结构体对照可以很容易找到各个成员的值。


`.strtab`为字符串表节，`.shstrtab`节与它格式相同，只是保存内容不同。`.shstrtab`中保存了节头中节名所用的字符串，而`.strtab`中包含了其他的字符串。如下列举出它们的内容。

```
$ hexdump -C -s 628 -n 100 hello.o
00000274  00 68 65 6c 6c 6f 2e 63  00 73 74 61 74 69 63 5f  |.hello.c.static_|
00000284  76 61 72 2e 31 39 33 38  00 73 74 61 74 69 63 5f  |var.1938.static_|
00000294  76 61 72 32 2e 31 39 33  39 00 67 6c 6f 62 61 6c  |var2.1939.global|
000002a4  5f 69 6e 69 74 5f 76 61  72 00 67 6c 6f 62 61 6c  |_init_var.global|
000002b4  5f 75 6e 69 6e 69 74 5f  76 61 72 00 6d 61 69 6e  |_uninit_var.main|
000002c4  00 70 75 74 73 00 6f 75  74 70 75 74 00 70 72 69  |.puts.output.pri|
000002d4  6e 74 66 00                                       |ntf.|

$ hexdump -C -s 816 -n 95 hello.o
00000330  00 2e 73 79 6d 74 61 62  00 2e 73 74 72 74 61 62  |..symtab..strtab|
00000340  00 2e 73 68 73 74 72 74  61 62 00 2e 72 65 6c 2e  |..shstrtab..rel.|
00000350  74 65 78 74 00 2e 64 61  74 61 00 2e 62 73 73 00  |text..data..bss.|
00000360  2e 72 6f 64 61 74 61 00  2e 63 6f 6d 6d 65 6e 74  |.rodata..comment|
00000370  00 2e 6e 6f 74 65 2e 47  4e 55 2d 73 74 61 63 6b  |..note.GNU-stack|
00000380  00 2e 72 65 6c 2e 65 68  5f 66 72 61 6d 65 00     |..rel.eh_frame.|
```

从上述打印出来的内容中可以发现，字符串表都是以0结尾的字符串的组合，而第一个字符串总为空串，即只有0结束符。从前面也看到很多`name`字段，它们的值为一个数字，这个数字即字符串表的索引，即该名字为从索引处开始到当前字符串结束这段字符即为它所用的内容。比如符号表的第七项内容为`000001c4  09 00 00 00 04 00 00 00  04 00 00 00 01 00 03 00  |................|`，它的`st_name`字段即为值`0x00000009`，从上面`.strtab`中查看下标为9开始的字符串为`static_var.1938`，即上面输出符号列表中索引为6的那一项。

在ELF头中最后一个成员`e_shstrndx`，它为节头表所用的字符串表所在节在节头表中的索引值。查看前面ELF头内容以及节头表索引，可以发现该字段值为10，正好对应`.shstrtab`节。

`.rel.text`和`.rel.eh_frame`两个节名字类似，都以字符串`.rel`开始，说明它们都是重定位节，后面半部分名称表示它所作用的节，即`.rel.text`中记录了代码节中的重定位信息。重定位节内容也为固定项组成，每一项都符合如下的C结构。

```
typedef struct elf32_rel {
  Elf32_Addr	r_offset;	// 需要重定位点在节中偏移
  Elf32_Word	r_info;		// 重定位点类型和符号，低8位为入口类型，高24位为符号表下标
} Elf32_Rel;
```

```
$ readelf -r hello.o 

重定位节 '.rel.text' 位于偏移量 0x2d8 含有 10 个条目：
 偏移量     信息    类型              符号值      符号名称
00000015  00000501 R_386_32          00000000   .rodata
0000001a  00000e02 R_386_PC32        00000000   puts
00000023  00000b01 R_386_32          00000000   global_init_var
00000028  00000301 R_386_32          00000000   .data
00000033  00000501 R_386_32          00000000   .rodata
00000038  00000f02 R_386_PC32        00000000   output
00000041  00000401 R_386_32          00000000   .bss
0000004a  00000401 R_386_32          00000000   .bss
00000053  00000501 R_386_32          00000000   .rodata
00000058  00001002 R_386_PC32        00000000   printf

重定位节 '.rel.eh_frame' 位于偏移量 0x328 含有 1 个条目：
 偏移量     信息    类型              符号值      符号名称
00000020  00000202 R_386_PC32        00000000   .text
```

对于这种重定位，在32位x86平台上有两种指令寻址需要进行修改：绝对近址32位寻址和相对近址32位寻址。重定位类型也是两种`R_386_32（1）`和`R_386_PC32（2）`分别对应`绝对寻址修正 S+A`和`相对寻址修正 S+A-P`，其中A为保存在待修正位置的值，P为被修正的位置（相对于节开始的便宜两或者虚拟地址，可以通过`r_offset`字段计算得到），S为符号的实际地址，即`r_info`的高24位指定的符号的实际地址。

比如以`hello.c`中的`global_init_var + static_var`两个变量重定位为例，其实它俩在编译后被分配到了`.data`节中，在`hello.o`中对于两个变量的访问如下汇编代码。

```
  21:	8b 15 00 00 00 00    	mov    0x0,%edx
  27:	a1 04 00 00 00       	mov    0x4,%eax
  2c:	01 d0                	add    %edx,%eax
```

即目标文件中无法确定变量的最终地址，这里使用值进行代替，`global_init_var`对应上面`8b 15`后的`00000000`值，而`static_var`则对应下面`a1`后的`00000004`。从上面重定位表中可以发现，`0x23`偏移处对应的信息为`00000b01`，即`R_386_32`类型重定位，对应的符号在符号表中索引为`0x0b`，查看前面打印符号表可知它对应的为`global_init_var`，而这个变量所在的节的索引为3，同理参考前面节表可以确定为`.data`节。那么最终重定位时，值为`.data节在可执行文件中的地址 + 0(A)`，其实就是`.data`节的第一个四字节，值为1；同理可以确定`static_var`在`.data`节的第二个四字节数据上。对应前面打印的`.data`节的数据，正好与此处对应。

```
$ hexdump -C -s 728 -n 80 hello.o
000002d8  15 00 00 00 01 05 00 00  1a 00 00 00 02 0e 00 00  |................|
000002e8  23 00 00 00 01 0b 00 00  28 00 00 00 01 03 00 00  |#.......(.......|
000002f8  33 00 00 00 01 05 00 00  38 00 00 00 02 0f 00 00  |3.......8.......|
00000308  41 00 00 00 01 04 00 00  4a 00 00 00 01 04 00 00  |A.......J.......|
00000318  53 00 00 00 01 05 00 00  58 00 00 00 02 10 00 00  |S.......X.......|
```

其实还有另外一种重定位表格式，如下为表项的C语言格式，它多了一个明确的加数，即`r_addend`。在计算重定位地址时需要额外加上这个值。

```
typedef struct elf32_rela{
  Elf32_Addr	r_offset;
  Elf32_Word	r_info;
  Elf32_Sword	r_addend;
} Elf32_Rela;
```

还有一部分重要内容是`.debug*`节，它们是保存调试信息的节，这里编译时并未加入调试信息，因此编译出来的目标目标文件中并没有包含这些节。这块内容也相对复杂，以后有机会单独总结一篇。

###目标文件的链接###

链接就是将目标文件（`.o`）拼接成可执行文件，或者动态链接库。链接的主要内容是把各个模块之间相互引用的部分都处理好，使得各个模块可以正确衔接。

从原理上来讲，链接器就是把一些指令对其它符号地址的引用加以修正，可以正确引用。链接过程主要包括地址和空间分配，符号决议和重定位等步骤。

以我们的程序为例，`main()`函数中有调用`output()`函数，而在前面的内容中可以知道，编译过程中`hello.c`和`output.c`是分别单独编译为独立的模块。在编译过程中，`main()`函数并不知道`output()`函数的地址，所以编译器就将`output()`函数的地址搁置，等到最后链接时由连接器去将这些指令的目标地址修正。上一节中的汇编代码可以看到使用了如下这种相对地址来替代`output()`函数的最终地址。

```
37:	e8 fc ff ff ff       	call   38 <main+0x38>
```

链接的两个步骤，第一是进行空间和地址分配，即扫描所有输入的目标文件，获得它们各个节的长度，属性和位置，并将其中符号表中所有符号定义和符号引用收集起来。这时就大致可以确定各个目标文件的节在最终文件中的位置，各节的地址也就确定下来。第二步是进行符号解析与重定位，读取输入文件中节的数据，重定位信息，进行符号解析与重定位，调整代码中的地址等。

在前面的`hello.o`解析中，我们看到了符号表信息，以及文件中的重定位信息。前面以全局变量`global_init_var + static_var`举例，解析了如何进行符号解析与重定位。其实那里面有一个量是未定的，即符号所在节的基地址，这个地址在第一步时进行分配。

简单了解了链接过程，使用如下的命令可以将我们编译出来的两个目标文件链接为可执行文件。

```
ld -m32 -march=i686 -m elf_i386 \
	-dynamic-linker /lib/ld-linux.so.2 \
	-z relro \
	/usr/lib32/crt1.o \
	/usr/lib32/crti.o \
	/usr/lib/gcc/x86_64-linux-gnu/5/32/crtbegin.o \
	-L/usr/lib/gcc/x86_64-linux-gnu/5/32 \
	-L/usr/lib32 \
	-L. \
	./hello.o \
	./output.o \
	-lgcc -lgcc_s -lc \
	/usr/lib/gcc/x86_64-linux-gnu/5/32/crtend.o \
	/usr/lib32/crtn.o
```

这里需要说明一下，因为代码中用到了C运行时库，并且真正要链接为可执行文件也需要C运行时库支持。当然了不使用C运行时库也可以链接为最终的可执行文件，但是那样会比较麻烦，所以这里将需要链接的C运行时库的前端和后端补充代码直接加进来。

###可执行文件格式###



| 常用节名 |            说明            |
|----------|---------------------------|
|.debug*   | 调试信息相关的节           |
|.line     | 调试时的行号表，源代码与编译后指令对应表 |
|.hash     | 符号哈希表                 |
|.note     | 额外的编译器信息，比如程序的公司名，发布版本号等 |



By Andy@2018-09-13 10:32:18


