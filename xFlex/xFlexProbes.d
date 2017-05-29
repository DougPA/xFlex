/*

    xFlexProbes.d
    xFlex

    Created by Douglas Adams on 2/22/16.
    Copyright © 2016 Douglas Adams. All rights reserved.

    USAGE:

    This file must be compiled (using Terminal in the same directory as this file) using:
        dtrace -h -s xFlexProbes.d

    Compilation will produce xFlexProbes.h (in the same directory)

    An entry must then be added into xFlexProbesWrapper.h for each probe

    xFlexProbesWrapper.h must be "imported" in the xFlex-Bridging-Header.h" file

*/

provider xFlex {

    /* Min, Max & Avg of an Integer value */
	probe integerValueRange(int);

};