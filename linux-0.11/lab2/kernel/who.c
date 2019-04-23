
#include "linux/kernel.h"
#include "string.h"
#include "asm/segment.h"

char g_ami[24] = {};

int sys_iam(const char *name)
{
	char szTemp[24];
	memset(szTemp, 0, strlen(szTemp));
	
	int c = 0;
	int i = 0;
	for (c=0; (c = get_fs_byte(name)) != '\0' && i < 24; i++, c = 0)
		szTemp[i] = c;

	if (i <= 23)
	{
		strcpy(g_ami, szTemp);
		return i;
	}

	return -1;
}

int sys_whoami(char * name, unsigned int len)
{
	int amilen = strlen(g_ami);
	if (len <= amilen)
		return -1;
	else
	{
		int i = 0;
		for (i = 0; i < amilen; i++)
		{
			put_fs_byte(g_ami[i], name + i);
		}
	}

	return amilen;
}
