/*
gsmax_init.c
Initialize the annual maximum leaf-scale stomatal conductance
parameters for bgc simulation

*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*
Biome-BGC version 4.2 (final release)
See copyright.txt for Copyright information
*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*-*

Johan A. Elkink  4 Nov 2017
*/

#include "pointbgc.h"

int gsmax_init(file init, gsmax_control_struct* gsmax, int simyears)
{
	int ok = 1;
	int i;
	char key1[] = "GSMAX_CONTROL";
	char keyword[80];
	char junk[80];
	file temp;
	int reccount = 0;
	/********************************************************************
	**                                                                 **
	** Begin reading initialization file block starting with keyword:  **
	** GSMAX_CONTROL                                                     **
	**                                                                 **
	********************************************************************/

	/* scan for the stomatal conductance block keyword, exit if not next */
	if (ok && scan_value(init, keyword, 's'))
	{
		bgc_printf(BV_ERROR, "Error reading keyword, smax_init()\n");
		ok=0;
	}
	if (ok && strcmp(keyword,key1))
	{
		bgc_printf(BV_ERROR, "Expecting keyword --> %s in %s\n",key1,init.name);
		ok=0;
	}

	/* begin reading gsmax control information */
	if (ok && scan_value(init, &gsmax->vargsmax, 'i'))
	{
		bgc_printf(BV_ERROR, "Error reading variable gsmax flag: gsmax_init()\n");
		ok=0;
	}

	/* if using variable GSMAX file, open it, otherwise
	discard the next line of the ini file */
	if (ok && gsmax->vargsmax)
	{
    	if (scan_open(init,&temp,'r'))
		{
			bgc_printf(BV_ERROR, "Error opening annual GSMAX file\n");
			ok=0;
		}

		/* Find the number of lines in the file*/
		/* Then use that number to malloc the appropriate arrays */
		while(fscanf(temp.ptr,"%*lf%*lf") != EOF)
		{
			reccount++;
		}
		rewind(temp.ptr);

		/* Store the total number of GSMAX records found in the gsmaxvals variable */
		gsmax->gsmaxvals = reccount;
		bgc_printf(BV_DIAG,"Found: %i GSMAX records in gsmax_init()\n",reccount);

		/* allocate space for the annual GSMAX array */
		if (ok && !(gsmax->gsmaxms_array = (double*) malloc(reccount *
			sizeof(double))))
		{
			bgc_printf(BV_ERROR, "Error allocating for annual GSMAX array, gsmax_init()\n");
			ok=0;
		}
		if (ok && !(gsmax->gsmaxyear_array = (int*) malloc(reccount *
			sizeof(int))))
		{
			bgc_printf(BV_ERROR, "Error allocating for annual GSMAX year array, gsmax_init()\n");
			ok=0;
		}
		/* read year and maximum conductance for each simyear */
		for (i=0 ; ok && i<reccount ; i++)
		{
			if (fscanf(temp.ptr,"%i%lf",
				&(gsmax->gsmaxyear_array[i]),&(gsmax->gsmaxms_array[i]))==EOF)
			{
				bgc_printf(BV_ERROR, "Error reading annual GSMAX array, ctrl_init()\n");
				bgc_printf(BV_ERROR, "Note: file must contain a pair of values for each\n");
				bgc_printf(BV_ERROR, "simyear: year and GSMAX.\n");
				ok=0;
			}
			// bgc_printf(BV_DIAG, "GSMAX value read: %i %lf\n", gsmax->gsmaxyear_array[i], gsmax->gsmaxms_array[i]);
			if (gsmax->gsmaxms_array[i] < 0.0)
			{
				bgc_printf(BV_ERROR, "Error in gsmax_init(): GSMAX (m/s) must be positive\n");
				ok=0;
			}
		}
		fclose(temp.ptr);
	}
	else
	{
		if (scan_value(init, junk, 's'))
		{
			bgc_printf(BV_ERROR, "Error scanning annual gsmax filename\n");
			ok=0;
		}
	}

	return (!ok);
}
