/*
 *  linux/mm/page.s
 *
 *  (C) 1991  Linus Torvalds
 */

/*
 * page.s contains the low-level page-exception code.
 * the real work is done in mm.c
 */

.globl page_fault

page_fault:
	xchgl %eax,(%esp) # 将错误码交换到 eax中 
	pushl %ecx
	pushl %edx
	push %ds
	push %es
	push %fs
	movl $0x10,%edx # 修正 ds/es/fs等段寄存器值,志向内核
	mov %dx,%ds
	mov %dx,%es
	mov %dx,%fs
	movl %cr2,%edx  # 将 cr2 寄存器,即页错误地址 放入edx,然后压入栈
	pushl %edx
	pushl %eax
	testl $1,%eax   # 错误码最低位为1,则为写保护,否则为缺页
	jne 1f
	call do_no_page
	jmp 2f
1:	call do_wp_page
2:	addl $8,%esp
	pop %fs
	pop %es
	pop %ds
	popl %edx
	popl %ecx
	popl %eax
	iret
