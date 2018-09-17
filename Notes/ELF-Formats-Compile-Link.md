#ELF格式解析#

ELF作为Linux系统下的可执行文件与动态库的格式，一直没有完全明白，其中一个原因是ELF格式的很多教程参考ELF官方文档，讲解过程将目标文件(.o)和ELF文件格式混起来讲解，最终导致混乱，两个都没能清晰说明白。再者，很多教程也没有结合实例进行讲解，对`.o`，`a.out`和`.so`文件进行区分对比，导致很多概念混淆。

这一篇文章想从编译链接开始，首先总结编译中涉及到ELF格式的一些知识，然后将编译的结果`.o`文件进行分析说明；再总结链接中关于ELF格式的一些知识，最后将ELF文件和`.so`文件进行分析说明。希望最终通过这篇文章的总结，能够对编译链接过程有一个简单认识，更重要的是能够理解ELF文件的内容。

文章里面会列举很多完整的代码与解析结果，这会导致文章很长，这部分只分析到ELF可执行文件格式，至于动态库的格式后面再另外一篇续中继续解析。

我们以如下的代码为例，对整篇文章中涉及的文件进行编译生成。

```
// hello.c
#include <stdio.h>
#include "output.h"

int main()
{
	printf("Before call Func.\n");
	output("Hello World!\n");
	printf("After call Func.\n");

	return 0;
}

// output.h
#pragma once

int output(const char * str);

// output.c
#include "output.h"
#include <stdio.h>

int output(const char * str)
{
	if (0 == str)
	{
		return -1;
	}

	printf("%s: %s", __func__, str);
	return 0;
}
```

###编译中的ELF格式知识###

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
  Elf32_Word	e_version;	// CPU类型，
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
  unsigned char e_pad[9];		// 未使用字节，设置为0
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


###链接中的ELF格式知识###

链接就是将目标文件（`.o`）拼接成可执行文件，或者动态链接库。链接的主要内容是把各个模块之间相互引用的部分都处理好，使得各个模块可以正确衔接。

从原理上来讲，链接器就是把一些指令对其它符号地址的引用加以修正，可以正确引用。链接过程主要包括地址和空间分配，符号决议和重定位等步骤。

以我们的程序为例，`main()`函数中有调用`output()`函数，而在前面的内容中可以知道，其实编译过程中`hello.c`和`output.c`是分别单独编译为独立的模块的。那其实在编译过程中，`main()`函数并不知道`output`函数的地址，所以编译器就将`output()`函数地址搁置，等到最后链接时由连接器去将这些指令的目标地址修正。

在前面分析目标文件(`.o`)中，我们看到每个文件中都有重定位信息，包括重定位点等信息。

###可执行文件和动态库格式###


###ELF中额外知识点###


By Andy@2018-09-13 10:32:18


