#ELF格式解析#

ELF作为Linux系统下的可执行文件与动态库的格式，一直没有完全明白，其中一个原因是ELF格式说明的很多教程参考ELF官方文档，讲解过程将目标文件(.o)和ELF文件格式混起来讲解，最终导致没能完全说明白。再者，很多教程也没有结合实例进行讲解，并且对`.o`，`a.out`和`.so`文件进行区分对比，导致很多概念混淆。

这一篇文章想从编译链接开始，首先总结编译中涉及到ELF格式的一些知识，然后将编译的结果`.o`文件进行分析说明；再总结链接中关于ELF格式的一些知识，最后将ELF文件和`.so`文件进行分析说明。希望最终通过这篇文章的总结，能够对编译链接过程有一个简单认识，更重要的是彻底理解ELF文件的内容。

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

编译过程又可以细分为预处理，编译，汇编三个过程。预处理主要是将头文件，宏定义，条件编译等进行处理，可以使用`gcc -E hello.c -o hello.i`对C语言源代码进行预处理，预处理结果是一个可读的`.i`文本文件。编译主要是将预处理后的文件进行编译，生成汇编代码，可以使用`gcc -S hello.i -o hello.s`对预处理的文件进行编译，编译后的文件是汇编文件`.s`，它也是可读的文本文件。最后一步是汇编，即将汇编文件汇编为二进制文件，即下一节中要分析的目标文件。汇编可以通过`gcc`进行，也可以使用汇编程序`as`来完成，`as hello.s -o hello.o`或`gcc -c hello.s -o hello.o`。

其实从上面的三个过程中可以看出，预处理就是对源代码的处理，它不会对编译生成的目标文件产生影响。对编译生成目标文件有影响的就是后面的两个过程，编译和汇编。

编译可以再次进行细分，即源码的词法分析，语法分析，语义分析，中间语言生成，目标代码生成。以中间语言为界限，编译器又被分为了编译前端和编译后端。编译前端完成中间语言生成，中间语言是与机器无关的跨平台代码；编译后端则将中间代码转换为目标机器代码，对于我们这里的例子来讲即生成i386兼容的汇编代码。

编译后端主要包括了代码生成器和目标代码优化器。代码生成器将中间代码转换为目标机器代码，这个过程直接依赖于目标机器，不同的机器有不同的字长，寄存器和整数类型。其实这块就和最终的目标文件有关系了，对于X86的平台，汇编中变量地址长度为4字节。目标代码优化也是目标平台紧相关的，对最终生成的代码长度有直接影响。

```
$ gcc -S -g -m32 hello.c -o hello.s
$ gcc -S -g -m32 output.c -o output.s
```

其实到目前生成目标平台代码为止，我们已经能看到最终要放到目标文件中的一些数据了，如下为`hello.c`编译为汇编代码文件后的`hello.s`的内容。

```
	.file	"hello.c"
	.text
.Ltext0:
	.section	.rodata
.LC0:
	.string	"Before call Func."
.LC1:
	.string	"Hello World!\n"
.LC2:
	.string	"After call Func."
	.text
	.globl	main
	.type	main, @function
main:
.LFB0:
	.file 1 "hello.c"
	.loc 1 6 0
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
	.loc 1 7 0
	subl	$12, %esp
	pushl	$.LC0
	call	puts
	addl	$16, %esp
	.loc 1 9 0
	subl	$12, %esp
	pushl	$.LC1
	call	output
	addl	$16, %esp
	.loc 1 10 0
	subl	$12, %esp
	pushl	$.LC2
	call	puts
	addl	$16, %esp
	.loc 1 12 0
	movl	$0, %eax
	.loc 1 13 0
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
.Letext0:
	.section	.debug_info,"",@progbits
.Ldebug_info0:
	.long	0x8b
	.value	0x4
	.long	.Ldebug_abbrev0
	.byte	0x4
	.uleb128 0x1
	.long	.LASF11
	.byte	0xc
	.long	.LASF12
	.long	.LASF13
	.long	.Ltext0
	.long	.Letext0-.Ltext0
	.long	.Ldebug_line0
	.uleb128 0x2
	.byte	0x4
	.byte	0x7
	.long	.LASF0
	.uleb128 0x2
	.byte	0x1
	.byte	0x8
	.long	.LASF1
	.uleb128 0x2
	.byte	0x2
	.byte	0x7
	.long	.LASF2
	.uleb128 0x2
	.byte	0x4
	.byte	0x7
	.long	.LASF3
	.uleb128 0x2
	.byte	0x1
	.byte	0x6
	.long	.LASF4
	.uleb128 0x2
	.byte	0x2
	.byte	0x5
	.long	.LASF5
	.uleb128 0x3
	.byte	0x4
	.byte	0x5
	.string	"int"
	.uleb128 0x2
	.byte	0x8
	.byte	0x5
	.long	.LASF6
	.uleb128 0x2
	.byte	0x8
	.byte	0x7
	.long	.LASF7
	.uleb128 0x2
	.byte	0x4
	.byte	0x5
	.long	.LASF8
	.uleb128 0x2
	.byte	0x4
	.byte	0x7
	.long	.LASF9
	.uleb128 0x2
	.byte	0x1
	.byte	0x6
	.long	.LASF10
	.uleb128 0x4
	.long	.LASF14
	.byte	0x1
	.byte	0x5
	.long	0x4f
	.long	.LFB0
	.long	.LFE0-.LFB0
	.uleb128 0x1
	.byte	0x9c
	.byte	0
	.section	.debug_abbrev,"",@progbits
.Ldebug_abbrev0:
	.uleb128 0x1
	.uleb128 0x11
	.byte	0x1
	.uleb128 0x25
	.uleb128 0xe
	.uleb128 0x13
	.uleb128 0xb
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x1b
	.uleb128 0xe
	.uleb128 0x11
	.uleb128 0x1
	.uleb128 0x12
	.uleb128 0x6
	.uleb128 0x10
	.uleb128 0x17
	.byte	0
	.byte	0
	.uleb128 0x2
	.uleb128 0x24
	.byte	0
	.uleb128 0xb
	.uleb128 0xb
	.uleb128 0x3e
	.uleb128 0xb
	.uleb128 0x3
	.uleb128 0xe
	.byte	0
	.byte	0
	.uleb128 0x3
	.uleb128 0x24
	.byte	0
	.uleb128 0xb
	.uleb128 0xb
	.uleb128 0x3e
	.uleb128 0xb
	.uleb128 0x3
	.uleb128 0x8
	.byte	0
	.byte	0
	.uleb128 0x4
	.uleb128 0x2e
	.byte	0
	.uleb128 0x3f
	.uleb128 0x19
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x11
	.uleb128 0x1
	.uleb128 0x12
	.uleb128 0x6
	.uleb128 0x40
	.uleb128 0x18
	.uleb128 0x2116
	.uleb128 0x19
	.byte	0
	.byte	0
	.byte	0
	.section	.debug_aranges,"",@progbits
	.long	0x1c
	.value	0x2
	.long	.Ldebug_info0
	.byte	0x4
	.byte	0
	.value	0
	.value	0
	.long	.Ltext0
	.long	.Letext0-.Ltext0
	.long	0
	.long	0
	.section	.debug_line,"",@progbits
.Ldebug_line0:
	.section	.debug_str,"MS",@progbits,1
.LASF6:
	.string	"long long int"
.LASF0:
	.string	"unsigned int"
.LASF11:
	.string	"GNU C11 5.4.0 20160609 -m32 -mtune=generic -march=i686 -g -fstack-protector-strong"
.LASF3:
	.string	"long unsigned int"
.LASF7:
	.string	"long long unsigned int"
.LASF10:
	.string	"char"
.LASF1:
	.string	"unsigned char"
.LASF13:
	.string	"/home/andy/github/AUPEProgram/elf"
.LASF14:
	.string	"main"
.LASF8:
	.string	"long int"
.LASF2:
	.string	"short unsigned int"
.LASF4:
	.string	"signed char"
.LASF5:
	.string	"short int"
.LASF12:
	.string	"hello.c"
.LASF9:
	.string	"sizetype"
	.ident	"GCC: (Ubuntu 5.4.0-6ubuntu1~16.04.10) 5.4.0 20160609"
	.section	.note.GNU-stack,"",@progbits
```

如下为`output.c`编译为汇编代码文件后的`output.s`的内容。

```
	.file	"output.c"
	.text
.Ltext0:
	.section	.rodata
.LC0:
	.string	"%s: %s"
	.text
	.globl	output
	.type	output, @function
output:
.LFB0:
	.file 1 "output.c"
	.loc 1 6 0
	.cfi_startproc
	pushl	%ebp
	.cfi_def_cfa_offset 8
	.cfi_offset 5, -8
	movl	%esp, %ebp
	.cfi_def_cfa_register 5
	subl	$8, %esp
	.loc 1 7 0
	cmpl	$0, 8(%ebp)
	jne	.L2
	.loc 1 9 0
	movl	$-1, %eax
	jmp	.L3
.L2:
	.loc 1 12 0
	subl	$4, %esp
	pushl	8(%ebp)
	pushl	$__func__.1936
	pushl	$.LC0
	call	printf
	addl	$16, %esp
	.loc 1 13 0
	movl	$0, %eax
.L3:
	.loc 1 14 0
	leave
	.cfi_restore 5
	.cfi_def_cfa 4, 4
	ret
	.cfi_endproc
.LFE0:
	.size	output, .-output
	.section	.rodata
	.align 4
	.type	__func__.1936, @object
	.size	__func__.1936, 7
__func__.1936:
	.string	"output"
	.text
.Letext0:
	.section	.debug_info,"",@progbits
.Ldebug_info0:
	.long	0xcd
	.value	0x4
	.long	.Ldebug_abbrev0
	.byte	0x4
	.uleb128 0x1
	.long	.LASF11
	.byte	0xc
	.long	.LASF12
	.long	.LASF13
	.long	.Ltext0
	.long	.Letext0-.Ltext0
	.long	.Ldebug_line0
	.uleb128 0x2
	.byte	0x4
	.byte	0x7
	.long	.LASF0
	.uleb128 0x2
	.byte	0x1
	.byte	0x8
	.long	.LASF1
	.uleb128 0x2
	.byte	0x2
	.byte	0x7
	.long	.LASF2
	.uleb128 0x2
	.byte	0x4
	.byte	0x7
	.long	.LASF3
	.uleb128 0x2
	.byte	0x1
	.byte	0x6
	.long	.LASF4
	.uleb128 0x2
	.byte	0x2
	.byte	0x5
	.long	.LASF5
	.uleb128 0x3
	.byte	0x4
	.byte	0x5
	.string	"int"
	.uleb128 0x2
	.byte	0x8
	.byte	0x5
	.long	.LASF6
	.uleb128 0x2
	.byte	0x8
	.byte	0x7
	.long	.LASF7
	.uleb128 0x2
	.byte	0x4
	.byte	0x5
	.long	.LASF8
	.uleb128 0x2
	.byte	0x4
	.byte	0x7
	.long	.LASF9
	.uleb128 0x2
	.byte	0x1
	.byte	0x6
	.long	.LASF10
	.uleb128 0x4
	.byte	0x4
	.long	0x7f
	.uleb128 0x5
	.long	0x72
	.uleb128 0x6
	.long	.LASF14
	.byte	0x1
	.byte	0x5
	.long	0x4f
	.long	.LFB0
	.long	.LFE0-.LFB0
	.uleb128 0x1
	.byte	0x9c
	.long	0xbb
	.uleb128 0x7
	.string	"str"
	.byte	0x1
	.byte	0x5
	.long	0x79
	.uleb128 0x2
	.byte	0x91
	.sleb128 0
	.uleb128 0x8
	.long	.LASF15
	.long	0xcb
	.uleb128 0x5
	.byte	0x3
	.long	__func__.1936
	.byte	0
	.uleb128 0x9
	.long	0x7f
	.long	0xcb
	.uleb128 0xa
	.long	0x6b
	.byte	0x6
	.byte	0
	.uleb128 0x5
	.long	0xbb
	.byte	0
	.section	.debug_abbrev,"",@progbits
.Ldebug_abbrev0:
	.uleb128 0x1
	.uleb128 0x11
	.byte	0x1
	.uleb128 0x25
	.uleb128 0xe
	.uleb128 0x13
	.uleb128 0xb
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x1b
	.uleb128 0xe
	.uleb128 0x11
	.uleb128 0x1
	.uleb128 0x12
	.uleb128 0x6
	.uleb128 0x10
	.uleb128 0x17
	.byte	0
	.byte	0
	.uleb128 0x2
	.uleb128 0x24
	.byte	0
	.uleb128 0xb
	.uleb128 0xb
	.uleb128 0x3e
	.uleb128 0xb
	.uleb128 0x3
	.uleb128 0xe
	.byte	0
	.byte	0
	.uleb128 0x3
	.uleb128 0x24
	.byte	0
	.uleb128 0xb
	.uleb128 0xb
	.uleb128 0x3e
	.uleb128 0xb
	.uleb128 0x3
	.uleb128 0x8
	.byte	0
	.byte	0
	.uleb128 0x4
	.uleb128 0xf
	.byte	0
	.uleb128 0xb
	.uleb128 0xb
	.uleb128 0x49
	.uleb128 0x13
	.byte	0
	.byte	0
	.uleb128 0x5
	.uleb128 0x26
	.byte	0
	.uleb128 0x49
	.uleb128 0x13
	.byte	0
	.byte	0
	.uleb128 0x6
	.uleb128 0x2e
	.byte	0x1
	.uleb128 0x3f
	.uleb128 0x19
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x27
	.uleb128 0x19
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x11
	.uleb128 0x1
	.uleb128 0x12
	.uleb128 0x6
	.uleb128 0x40
	.uleb128 0x18
	.uleb128 0x2116
	.uleb128 0x19
	.uleb128 0x1
	.uleb128 0x13
	.byte	0
	.byte	0
	.uleb128 0x7
	.uleb128 0x5
	.byte	0
	.uleb128 0x3
	.uleb128 0x8
	.uleb128 0x3a
	.uleb128 0xb
	.uleb128 0x3b
	.uleb128 0xb
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x2
	.uleb128 0x18
	.byte	0
	.byte	0
	.uleb128 0x8
	.uleb128 0x34
	.byte	0
	.uleb128 0x3
	.uleb128 0xe
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x34
	.uleb128 0x19
	.uleb128 0x2
	.uleb128 0x18
	.byte	0
	.byte	0
	.uleb128 0x9
	.uleb128 0x1
	.byte	0x1
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x1
	.uleb128 0x13
	.byte	0
	.byte	0
	.uleb128 0xa
	.uleb128 0x21
	.byte	0
	.uleb128 0x49
	.uleb128 0x13
	.uleb128 0x2f
	.uleb128 0xb
	.byte	0
	.byte	0
	.byte	0
	.section	.debug_aranges,"",@progbits
	.long	0x1c
	.value	0x2
	.long	.Ldebug_info0
	.byte	0x4
	.byte	0
	.value	0
	.value	0
	.long	.Ltext0
	.long	.Letext0-.Ltext0
	.long	0
	.long	0
	.section	.debug_line,"",@progbits
.Ldebug_line0:
	.section	.debug_str,"MS",@progbits,1
.LASF6:
	.string	"long long int"
.LASF2:
	.string	"short unsigned int"
.LASF0:
	.string	"unsigned int"
.LASF11:
	.string	"GNU C11 5.4.0 20160609 -m32 -mtune=generic -march=i686 -g -fstack-protector-strong"
.LASF3:
	.string	"long unsigned int"
.LASF7:
	.string	"long long unsigned int"
.LASF10:
	.string	"char"
.LASF14:
	.string	"output"
.LASF1:
	.string	"unsigned char"
.LASF13:
	.string	"/home/andy/github/AUPEProgram/elf"
.LASF8:
	.string	"long int"
.LASF15:
	.string	"__func__"
.LASF4:
	.string	"signed char"
.LASF5:
	.string	"short int"
.LASF12:
	.string	"output.c"
.LASF9:
	.string	"sizetype"
	.ident	"GCC: (Ubuntu 5.4.0-6ubuntu1~16.04.10) 5.4.0 20160609"
	.section	.note.GNU-stack,"",@progbits
```

可见此时对于函数和变量的引用都是使用符号，比如`main()`函数中调用`output()`函数，对其引用仍然是`call output`。

再经过汇编器完成代码的汇编之后，就变成了目标文件(`.o`)。目标文件中保存了二进制的代码，这块是下一节要分析的内容。使用如下命令，分别将两个`.s`文件汇编为对应的目标文件。

```
$ as --32 hello.s -o hello.o
$ as --32 output.s -o output.o
```

> 注： 编译程序，将整个编译过程打印出来可以使用这个命令，`gcc -v -m32 -g hello.c output.c`。X64系统上编译的X86的程序，所以要加入`-m32`

###目标文件格式###

上一节中介绍到编译过程中生成的目标文件，我们这个例子中即`hello.o`和`output.o`。

编译器编译源代码后生成的文件叫做目标文件，它已经是二进制文件了，即"可执行文件"。由于它们没有经过链接，其中引用的跨模块的符号引用都是假设值，直接执行肯定会出现错误。尽管如此，目标文件本身其实就是按照可执行文件格式存储的，和真正可以执行的可执行文件在结构上略有差异。

PC上流行的可执行文件主要有Windows下的PE（Portable Executable）和Linux上的ELF（Executable Linkable Format），它们都是`COFF`的变种。目标文件就是源码编译后未链接的中间文件，即Windows上的`.obj`和Linux上的`.o`，上面说了它们和各自对应的可执行文件内容和结构很相似。Windows上统称`PE-COFF`文件格式，Linux上统称`ELF`。动态链接库也都按照可执行文件格式存储，即Windows上的`DLL(Dynamic Linking Library)`和Linux上的`SO`库。

目标文件中的内容其实从上面汇编中也大概可以看出来，包括指令，数据，除此之外还需要符号表，调试信息，字符串等链接中所需信息。目标文件将这些信息按照不同的属性进行分类，然后将它们存储到不同的节或段中。一个简单的目标文件格式(以ELF为例)如下：

|   ELF Header  |
|---------------|
| .text section |
| .data section |
| .bss section  |

ELF文件的开始处为`文件头`，它描述整个文件的文件属性，包括文件类型，是否可执行，静态链接还是动态链接，入口地址，目标硬件，目标操作系统等。此外它还应该包括一个段表，用于描述后面的各个`Section`，比如段的偏移，长度等。`.text`段则主要保存代码，`.data`段则保存有初始值的全局变量和局部静态变量等，`.bss`则用于保存未初始化的全局变量和局部静态变量。


###链接中的ELF格式知识###

链接就是将目标文件（`.o`）拼接成可执行文件，或者动态链接库。链接的主要内容是把各个模块之间相互引用的部分都处理好，使得各个模块可以正确衔接。

从原理上来讲，链接器就是把一些指令对其它符号地址的引用加以修正，可以正确引用。链接过程主要包括地址和空间分配，符号决议和重定位等步骤。

以我们的程序为例，`main()`函数中有调用`output()`函数，而在前面的内容中可以知道，其实编译过程中`hello.c`和`output.c`是分别单独编译为独立的模块的。那其实在编译过程中，`main()`函数并不知道`output`函数的地址，所以编译器就将`output()`函数地址搁置，等到最后链接时由连接器去将这些指令的目标地址修正。

在前面分析目标文件(`.o`)中，我们看到每个文件中都有重定位信息，包括重定位点等信息。

###可执行文件和动态库格式###


###ELF中额外知识点###


By Andy@2018-09-13 10:32:18


