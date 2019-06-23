
#include <errno.h>
#include <string.h>
#include <asm/segment.h>

static char iamname[24];

int sys_iam(const char* name)
{
	int nret = 0;	
	int i = 0;

	char tmp[25];
	memset(tmp, 0, sizeof(tmp));
	for (i = 0; i < 24; i++)
	{
		tmp[i]  = get_fs_byte(name + i);
		if (tmp[i] == '\0')
			break;
	}

	if (i > 23)
		nret = -(EINVAL);
	else
	{
		nret = i;
		strcpy(iamname, tmp);
	}

	return nret;	
}

int sys_whoami(char* name, unsigned int size)
{
	int nret = 0;
	int i = 0;

	if (size < 24)
		nret = -(EINVAL);
	else
	{
		for (i = 0; i < 24; i++)
			put_fs_byte(iamname[i], name + i);
		nret = strlen(iamname);
	}

	return nret;
}
