/*
 * Copyright (C) 2008 by Steven Schveighoffer
 * all rights reserved.
 *
 * Examples of how sets can be used.
 */
import dcollections.TreeMap;
import dcollections.HashMap;
import dcollections.ArrayList;
import std.stdio;

void printK(KeyedIterator!(int, int) s, string message)
{
    write(message ~ " [");
    foreach(k, v; s)
        writef(" %s=>%s", k, v);
    writeln(" ]");
}

void print(Iterator!(int) s, string message)
{
    write(message ~ " [");
    foreach(v; s)
        write(" ", v);
    writeln(" ]");
}

void main()
{
    auto treeMap = new TreeMap!(int, int);
    auto hashMap = new HashMap!(int, int);

    for(int i = 0; i < 10; i++)
        treeMap.set(i * i + 1, i);
    printK(treeMap, "filled in treeMap");
    
    //
    // add all the key/value pairs from treeMap to hashMap
    //
    hashMap.set(treeMap);
    printK(hashMap, "filled in hashMap");

    //
    // you can iterate the keys
    //
    print(hashMap.keys, "hashMap keys");

    //
    // you can compare maps
    //
    if(hashMap == treeMap)
        writeln("equal!");
    else
        writeln("not equal!");

    //
    // you can do intersect/remove operations
    //
    // removes all but the 5, 50, and 26 elements.  Note that 89 is not a key
    // in the set
    //
    hashMap.intersect(new ArrayList!(int)([5, 50, 26, 89]));
    printK(hashMap, "intersected hashMap");

    //
    // this removes the 5, 50, and 26 elements from treeMap
    //
    print(hashMap.keys, "hashmapKeys after intersect");
    treeMap.remove(hashMap.keys);
    printK(treeMap, "removed from treeMap");

    //
    // You can dup a map, and then add some keys/values to it
    //
    treeMap = treeMap.dup.set(hashMap).set(75, 80).set(23, 20).set(26, 50);
    printK(treeMap, "dup'd, recombined treeMap and hashMap");
}
