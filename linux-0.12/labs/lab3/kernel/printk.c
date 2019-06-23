/*
 *  linux/kernel/printk.c
 *
 *  (C) 1991  Linus Torvalds
 */

/*
 * When in kernel-mode, we cannot use printf, as fs is liable to
 * point to 'interesting' things. Make a printf with fs-saving, and
 * all is well.
 */
#include <stdarg.h>
#include <stddef.h>

#include <linux/kernel.h>
#include <linux/sched.h>
#include <sys/stat.h>

static char buf[1024];

extern int vsprintf(char * buf, const char * fmt, va_list args);

int printk(const char *fmt, ...)
{
	va_list args;
	int i;

	va_start(args, fmt);
	i=vsprintf(buf,fmt,args);
	va_end(args);
	console_print(buf);
	return i;
}

/* 进程新建(N)、进入就绪态(J)、进入运行态(R)、进入阻塞态(W)和退出(E) */
static char logbuf[1024];
int fprintk(int fd, const char *fmt, ...)
{
	va_list args;
	int count;
	struct file * file;
	struct m_inode * inode;

	va_start(args, fmt);
	count = vsprintf(logbuf, fmt, args);
	va_end(args);

	if (fd < 3)
	{
		__asm__("push %%fs\n\t"
				"push %%ds\n\t"
				"pop %%fs\n\t"
				"pushl %0\n\t"
				"pushl $logbuf\n\t"
				"pushl %1\n\t"
				"call sys_write\n\t"
				"addl $8, %%esp\n\t"
				"popl %0\n\t"
				"pop %%fs"
				::"r"(count), "r"(fd):"cx", "dx");
	}
	else
	{
		if(!(file=task[1]->filp[fd]))
			return 0;
		inode = file->f_inode;

		__asm__("push %%fs\n\t"
				"push %%ds\n\t"
				"pop %%fs\n\t"
				"pushl %0\n\t"
				"pushl $logbuf\n\t"
				"pushl %1\n\t"
				"pushl %2\n\t"
				"call file_write\n\t"
				"add $12, %%esp\n\t"
				"popl %0\n\t"
				"pop %%fs"
				::"r"(count), "r"(file), "r"(inode):"cx", "dx");
	}

	return count;
}
