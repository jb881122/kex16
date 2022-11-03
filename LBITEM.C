/**
	LBITEM.C - LB_GETITEMDATA/LB_SETITEMDATA handler
*/

#include "kex16.h"


typedef struct {
	WORD index;
	long value;
} LBDATA;
typedef LBDATA NEAR *NPLBDATA;

typedef struct {
	HWND hWnd;
	NPLBDATA data;
} LBWND;
typedef LBWND NEAR *NPLBWND;

NPLBWND lbList = NULL;

/**
	onLBGetItemData: Retrieves ListBox item data that was previously set
	Params:
		hWnd - the HWND of the ListBox
		index - the index of the ListBox item to retrieve data from
*/
long NEAR PASCAL onLBGetItemData(hWnd, index)
HWND hWnd;
WORD index;
{
	NPLBWND lbWnd;
	NPLBDATA lbData;

	/* For each window w/ data, check if the hWnd matches */
	for(lbWnd = ll_getfirst(lbList);
			lbWnd && lbWnd->hWnd != hWnd;
			lbWnd = ll_getnext(lbWnd));

	/* If we got to the end, exit */
	if(!lbWnd)
		return 0;

	/* For data item, check if the index matches */
	for(lbData = ll_getfirst(lbWnd->data);
			lbData && lbData->index != index;
			lbData = ll_getnext(lbData));

	/* If we got to the end, exit */
	if(!lbData)
		return 0;

	return lbData->value;
}

/**
	onLBSetItemData: Sets the data associated with a ListBox item
	Params:
		hWnd - the HWND of the ListBox
		index - the index of the ListBox item to set data for
		data - the data to set
*/
void NEAR PASCAL onLBSetItemData(hWnd, index, data)
HWND hWnd;
WORD index;
LONG data;
{
	NPLBWND lbWnd;
	NPLBDATA lbData;

	/* Do any windows have data? */
	if(!lbList) {

		/* No, create the list for it */
		lbList = ll_create(sizeof(LBWND));
		if(!lbList) {
			return;
		}
		lbWnd = lbList;
		lbWnd->hWnd = hWnd;
		lbWnd->data = NULL;
	} else {

		/* Yes, see if any window is the one we're looking for */
		for(lbWnd = ll_getfirst(lbList);
				lbWnd && lbWnd->hWnd != hWnd;
				lbWnd = ll_getnext(lbWnd));

		/* Was the window found? */
		if(!lbWnd) {

			/* No, add an item for it */
			lbWnd = ll_append(lbList);
			if(!lbWnd) {
				return;
			}
			lbWnd->hWnd = hWnd;
			lbWnd->data = NULL;
		}
	}

	/* Does the window have data? */
	if(!lbWnd->data) {

		/* No, create the list for it */
		lbWnd->data = ll_create(sizeof(LBDATA));
		if(!lbWnd->data) {
			return;
		}
		lbData = lbWnd->data;
		lbData->index = index;
	} else {

		/* Yes, see if any of the data is what we're looking for */
		for(lbData = ll_getfirst(lbWnd->data);
				lbData && lbData->index != index;
				lbData = ll_getnext(lbData));

		/* Was the data entry found? */
		if(!lbData) {

			/* No, add an item for it */
			lbData = ll_append(lbWnd->data);
			if(!lbData) {
				return;
			}
			lbData->index = index;
		}
	}

	/* Finally, the easy part: Set the data */
	lbData->value = data;
}

/**
	onWMDestroyLB: Removes all data associated with a ListBox
	Params:
		hWnd - the HWND of the ListBox
*/
void NEAR PASCAL onWMDestroyLB(hWnd)
HWND hWnd;
{
	NPLBWND lbWnd;
	NPLBDATA lbData;

	/* For each window w/ data, check if the hWnd matches */
	for(lbWnd = ll_getfirst(lbList);
			lbWnd && lbWnd->hWnd != hWnd;
			lbWnd = ll_getnext(lbWnd));

	/* If we got to the end, exit */
	if(!lbWnd)
		return;

	/* Get the data list from the window */
	lbData = lbWnd->data;

	/* Delete the window */
	lbList = ll_remove(lbWnd);

	/* Until there is no data left... */
	while(lbData) {

		/* Remove it */
		lbData = ll_remove(lbData);
	}
}

/**
	LBCleanup: Removes all ListBox data
*/
void NEAR PASCAL LBCleanup()
{
	/* Until there are no windows left... */
	while(lbList) {

		/* Get rid of the first window's data */
		onWMDestroyLB(lbList->hWnd);
	}
}
