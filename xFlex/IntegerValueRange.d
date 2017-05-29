/*

    IntegerValueRange.d
    xFlex

    Created by Douglas Adams on 2/22/16.
    Copyright © 2016 Douglas Adams. All rights reserved.

    Script to capture Min, Max & Avg Integer values

    USAGE:
        sudo dtrace -q -s IntegerValueRange.d

*/

dtrace:::BEGIN
{
    trace("BEGIN, IntegerValueRange.d\n");
}

xFlex*:::integerValueRange
{
    @min = min(arg0);
    @max = max(arg0);
    @avg = avg(arg0);
}

dtrace:::END
{
    printa("Float values: min: %@d max: %@d avg: %@d\n",
            @min,
            @max,
            @avg);

    trace("END, IntegerValueRange.d\n");
    exit(0);
}
