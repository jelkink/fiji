/*
get_gsmax.c
retrieve the appropriate GSMAX conductance for the current simulation year

*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
Biome-BGC version 4.2 (final release)
See copyright.txt for Copyright information
*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

Johan A. Elkink  4 Nov 2017
*/

#include "bgc.h"

double get_gsmax(gsmax_control_struct * gsmax,int simyr)
{
	int i;
	for(i = 0;i < gsmax->gsmaxvals;i++)
	{
		if(gsmax->gsmaxyear_array[i] == simyr)
		{
			return (gsmax->gsmaxms_array[i]);
		}
	}
	return(-999.9);
}
