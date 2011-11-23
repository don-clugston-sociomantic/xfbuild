/*********************************************************
   Copyright: (C) 2008-2010 by Steven Schveighoffer.
              All rights reserved

   License: Boost Software License version 1.0

   Permission is hereby granted, free of charge, to any person or organization
   obtaining a copy of the software and accompanying documentation covered by
   this license (the "Software") to use, reproduce, display, distribute,
   execute, and transmit the Software, and to prepare derivative works of the
   Software, and to permit third-parties to whom the Software is furnished to
   do so, all subject to the following:

   The copyright notices in the Software and this entire statement, including
   the above license grant, this restriction and the following disclaimer, must
   be included in all copies of the Software, in whole or in part, and all
   derivative works of the Software, unless such copies or derivative works are
   solely in the form of machine-executable object code generated by a source
   language processor.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
   SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
   FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
   ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
   DEALINGS IN THE SOFTWARE.

**********************************************************/
module dcollections.HashSet;

public import dcollections.model.Set;
public import dcollections.DefaultFunctions;
private import dcollections.Hash,
        dcollections.util;

version(unittest)
{
    import std.traits;
    import std.array;
    import std.range;
    static import std.algorithm;
    bool rangeEqual(V)(HashSet!V.range r, V[] arr)
    {
        //assert(std.algorithm.isSorted(arr));
        size_t len = 0;
        for(; !r.empty; ++len, r.popFront())
        {
            //if(std.algorithm.find(assumeSorted(arr), r.front).empty)
            if(std.algorithm.find(arr, r.front).empty)
                return false;
        }
        return len == arr.length;
    }
}

/**
 * A set implementation which uses a Hash to have near O(1) insertion,
 * deletion and lookup time.
 *
 * Adding an element can invalidate cursors depending on the implementation.
 *
 * Removing an element only invalidates cursors that were pointing at that
 * element.
 *
 * You can replace the Hash implementation with a custom implementation, the
 * Hash must be a struct template which can be instantiated with a single
 * template argument V, and must implement the following members (non-function
 * members can be properties unless otherwise specified):
 *
 *
 * parameters -> must be a struct with at least the following members:
 *   hashFunction -> the hash function to use (should be a HashFunction!(V))
 *   updateFunction -> the update function to use (should be an
 *                     UpdateFunction!(V))
 * 
 * void setup(parameters p) -> initializes the hash with the given parameters.
 *
 * size_t count -> count of the elements in the hash
 *
 * position -> must be a struct with the following member:
 *   ptr -> must define the following member:
 *     V value -> the value which is pointed to by this position (cannot be a
 *                property)
 *   position next -> must be the next value in the hash
 *   position prev -> must be the previous value in the hash
 *
 * bool add(V v) -> add the given value to the hash.  The hash of the value
 * will be given by hashFunction(v).  If the value already exists in the hash,
 * this should call updateFunction(v) and should not increment count.
 *
 * position begin -> must be a position that points to the very first valid
 * element in the hash, or end if no elements exist.
 *
 * position end -> must be a position that points to just past the very last
 * valid element.
 *
 * position find(V v) -> returns a position that points to the element that
 * contains v, or end if the element doesn't exist.
 *
 * position remove(position p) -> removes the given element from the hash,
 * returns the next valid element or end if p was last in the hash.
 *
 * void clear() -> removes all elements from the hash, sets count to 0.
 */
final class HashSet(V, alias ImplTemp=HashNoUpdate, alias hashFunction=DefaultHash) : Set!(V)
{
    version(unittest)
    {
        private enum doUnittest = isIntegral!V;

        bool arrayEqual(V[] arr)
        {
            if(length == arr.length)
            {
                foreach(v; arr)
                {
                    if(!contains(v))
                        return false;
                }
                return true;
            }
            return false;
        }
    }
    else
    {
        private enum doUnittest = false;
    }

    /**
     * an alias the the implementation template instantiation.
     */
    alias ImplTemp!(V, hashFunction) Impl;

    private Impl _hash;

    /**
     * A cursor for the hash set.
     */
    struct cursor
    {
        private Impl.position position;
        private bool _empty = false;

        /**
         * get the value at this position
         */
        @property inout(V) front() inout
        {
            assert(!_empty, "Attempting to read the value of an empty cursor of " ~ HashSet.stringof);
            return position.ptr.value;
        }

        /**
         * Tell if this cursor is empty (doesn't point to any value)
         */
        @property bool empty() const
        {
            return _empty;
        }

        /**
         * Move to the next element.
         */
        void popFront()
        {
            assert(!_empty, "Attempting to popFront() an empty cursor of " ~ HashSet.stringof);
            _empty = true;
            position = position.next;
        }

        /**
         * length of the cursor range, which is always either 0 or 1.
         */
        @property size_t length() const
        {
            return _empty ? 0 : 1;
        }

        /**
         * opIndex costs nothing, and it allows more algorithms to accept
         * cursors.
         */
        inout(V) opIndex(size_t idx) inout
        {
            assert(idx < length, "Attempt to access invalid index on cursor");
            return position.ptr.value;
        }

        /**
         * trivial save implementation to implement forward range
         * functionality.
         */
        @property inout(cursor) save() inout
        {
            return this;
        }

        /**
         * compare two cursors for equality.  Note that only the position of
         * the cursor is checked, whether it's empty or not is not checked.
         */
        bool opEquals(ref const cursor it) const
        {
            return it.position == position;
        }

        /*
         * TODO: uncomment this when compiler is sane!
         * 
         * compare two cursors for equality.  Note that only the position of
         * the cursor is checked, whether it's empty or not is not checked.
         */
        /*
        bool opEquals(const cursor it) const
        {
            return it.position == position;
        }*/
    }

    static if(doUnittest) unittest
    {
        
        auto hs = new HashSet;
        hs.add([1, 2, 3, 4, 5]);
        auto cu = hs.elemAt(3);
        assert(!cu.empty);
        assert(cu.front == 3);
        cu.popFront();
        assert(cu.empty);
        assert(hs.arrayEqual([1, 2, 3, 4, 5]));
    }

    /**
     * A range that can be used to iterate over the elements in the hash.
     */
    struct range
    {
        private Impl.position _begin;
        private Impl.position _end;

        /**
         * is the range empty?
         */
        @property bool empty() const
        {
            return _begin is _end;
        }

        /**
         * Get a cursor to the first element in the range
         */
        @property inout(cursor) begin() inout
        {
            return inout(cursor)(_begin, empty);
        }

        /**
         * Get a cursor to the end element in the range
         */
        @property inout(cursor) end() inout
        {
            return inout(cursor)(_end, true);
        }

        /**
         * Get the first value in the range
         */
        @property inout(V) front() inout
        {
            assert(!empty, "Attempting to read front of an empty range of " ~ HashSet.stringof);
            return _begin.ptr.value;
        }

        /**
         * Get the last value in the range
         */
        @property inout(V) back() inout
        {
            assert(!empty, "Attempting to read back of an empty range of " ~ HashSet.stringof);
            return _end.prev.ptr.value;
        }

        /**
         * Move the front of the range ahead one element
         */
        void popFront()
        {
            assert(!empty, "Attempting to popFront() an empty range of " ~ HashSet.stringof);
            _begin = _begin.next;
        }

        /**
         * Move the back of the range to the previous element
         */
        void popBack()
        {
            assert(!empty, "Attempting to popBack() an empty range of " ~ HashSet.stringof);
            _end = _end.prev;
        }

        /**
         * Implement save as required by forward ranges now.
         */
        @property inout(range) save() inout
        {
            return this;
        }
    }

    static if(doUnittest) unittest
    {
        auto hs = new HashSet;
        hs.add([1, 2, 3, 4, 5]);
        auto r = hs[];
        assert(rangeEqual(r, cast(V[])[1, 2, 3, 4, 5]));
        assert(r.front == hs.begin.front);
        assert(r.back != r.front);
        auto oldfront = r.front;
        auto oldback = r.back;
        r.popFront();
        r.popBack();
        assert(r.front != r.back);
        assert(r.front != oldfront);
        assert(r.back != oldback);

        auto b = r.begin;
        assert(!b.empty);
        assert(b.front == r.front);
        auto e = r.end;
        assert(e.empty);
    }

    /**
     * Determine if a cursor belongs to the hashset
     */
    bool belongs(const(cursor) c) const
    {
        // rely on the implementation to tell us
        return _hash.belongs(c.position);
    }

    /**
     * Determine if a range belongs to the hashset
     */
    bool belongs(const(range) r) const
    {
        return _hash.belongs(r._begin) && _hash.belongs(r._end);
    }

    static if(doUnittest) unittest
    {
        auto hs = new HashSet;
        hs.add([1, 2, 3, 4, 5]);
        auto cu = hs.elemAt(3);
        assert(cu.front == 3);
        assert(hs.belongs(cu));
        auto r = hs[hs.begin..cu];
        assert(hs.belongs(r));

        auto hs2 = hs.dup();
        assert(!hs2.belongs(cu));
        assert(!hs2.belongs(r));
    }

    /**
     * Iterate over the elements in the set, specifying which ones to remove.
     *
     * Use like this:
     *
     * ---------------
     * // remove all odd elements
     * foreach(ref doPurge, v; &hashSet.purge)
     * {
     *   doPurge = ((v & 1) == 1);
     * }
     * ---------------
     */
    int purge(scope int delegate(ref bool doPurge, ref V v) dg)
    {
        Impl.position it = _hash.begin;
        bool doPurge;
        int dgret = 0;
        Impl.position _end = _hash.end; // cache end so it isn't always being generated
        while(!dgret && it !is _end)
        {
            //
            // don't allow user to change value
            //
            V tmpvalue = it.ptr.value;
            doPurge = false;
            if((dgret = dg(doPurge, tmpvalue)) != 0)
                break;
            if(doPurge)
                it = _hash.remove(it);
            else
                it = it.next;
        }
        return dgret;
    }

    static if(doUnittest) unittest
    {
        auto hs = new HashSet;
        hs.add([0, 1, 2, 3, 4]);
        foreach(ref p, i; &hs.purge)
        {
            p = (i & 1);
        }

        assert(hs.arrayEqual([0, 2, 4]));
    }

    /**
     * iterate over the collection's values
     */
    int opApply(scope int delegate(ref V v) dg)
    {
        int _dg(ref bool doPurge, ref V v)
        {
            return dg(v);
        }
        return purge(&_dg);
    }

    static if(doUnittest) unittest
    {
        auto hs = new HashSet;
        hs.add([1, 2, 3, 4, 5]);
        size_t len = 0;
        foreach(i; hs)
        {
            assert(hs.contains(i));
            ++len;
        }
        assert(len == hs.length);
    }

    /**
     * Instantiate the hash set using the implementation parameters given.
     */
    this(V[] initialElems...)
    {
        _hash.setup();
        add(initialElems);
    }

    /**
     * Constructor which uses initialElems as the initial elements for the hash
     * set.
     */
    this(Iterator!V initialElems)
    {
        _hash.setup();
        add(initialElems);
    }

    static if(doUnittest) unittest
    {
        auto hs = new HashSet(1, 2, 3, 4, 5);
        auto hs2 = new HashSet(hs);
        assert(hs == hs2);
    }

    //
    // private constructor for dup
    //
    private this(ref Impl dupFrom)
    {
        _hash.setup();
        dupFrom.copyTo(_hash);
    }

    /**
     * Clear the collection of all elements
     */
    HashSet clear()
    {
        _hash.clear();
        return this;
    }

    static if(doUnittest) unittest
    {
        auto hs = new HashSet(1, 2, 3, 4, 5);
        //hs.add([1, 2, 3, 4, 5]);
        assert(hs.length == 5);
        hs.clear();
        assert(hs.length == 0);
    }

    /**
     * returns number of elements in the collection
     */
    @property size_t length() const
    {
        return _hash.count;
    }

    /**
     * returns a cursor to the first element in the collection.
     */
    @property inout(cursor) begin() inout
    {
        return inout(cursor)(_hash.begin, _hash.count == 0);
    }

    /**
     * returns a cursor that points just past the last element in the
     * collection.
     */
    @property inout(cursor) end() inout
    {
        return inout(cursor)(_hash.end, true);
    }

    /**
     * remove the element pointed at by the given cursor, returning an
     * cursor that points to the next element in the collection.
     *
     * Runs on average in O(1) time.
     */
    cursor remove(cursor it)
    {
        if(!it.empty)
        {
            it.position = _hash.remove(it.position);
        }
        it._empty = it.position is _hash.end;
        return it;
    }

    static if(doUnittest) unittest
    {
        auto hs = new HashSet;
        hs.add([1, 2, 3, 4, 5]);
        hs.remove(hs.elemAt(3));
        assert(hs.arrayEqual([1, 2, 4, 5]));
    }

    /**
     * remove all the elements in the given range.
     */
    cursor remove(range r)
    {
        auto b = r.begin;
        auto e = r.end;
        while(b != e)
        {
            b = remove(b);
        }
        return b;
    }

    static if(doUnittest) unittest
    {
        auto hs = new HashSet;
        hs.add([1, 2, 3, 4, 5]);
        auto r = hs[hs.elemAt(3)..hs.end];
        V[5] buf;
        auto remaining = std.algorithm.copy(hs[hs.begin..hs.elemAt(3)], buf[]);
        hs.remove(r);
        assert(hs.arrayEqual(buf[0..buf.length - remaining.length]));
        assert(!hs.contains(3));
    }

    /**
     * get a slice of all the elements in this hashmap.
     */
    inout(range) opSlice() inout
    {
        return inout(range)(_hash.begin, _hash.end);
    }

    /**
     * get a slice of the elements between the two cursors.  Runs on average
     * O(1) time.
     */
    inout(range) opSlice(inout(cursor) b, inout(cursor) e) inout
    {
        // for hash set, we only support ranges that begin on the first cursor,
        // or end on the last cursor.  This is because to check that b is
        // before e for arbitrary cursors would be possibly a long operation.
        // TODO: fix this when compiler is sane
        //if((b == begin && belongs(e)) || (e == end && belongs(b)))
        if((begin == b && belongs(e)) || (end == e && belongs(b)))
        {
            return inout(range)(b.position, e.position);
        }
        throw new Exception("invalid slice parameters to " ~ HashSet.stringof);
    }

    static if (doUnittest) unittest
    {
        auto hs = new HashSet;
        hs.add([1, 2, 3, 4, 5]);
        auto fr = hs[];
        fr.popFront();
        fr.popFront();
        auto cu = fr.begin;
        auto r = hs[hs.begin..cu];
        auto r2 = hs[cu..hs.end];
        foreach(x; r2)
        {
            assert(std.algorithm.find(r, x).empty);
        }
        assert(walkLength(r) + walkLength(r2) == hs.length);

        bool exceptioncaught = false;
        try
        {
            hs[cu..cu];
        }
        catch(Exception)
        {
            exceptioncaught = true;
        }
        assert(exceptioncaught);
    }


    /**
     * find the instance of a value in the collection.  Returns end if the
     * value is not present.
     *
     * Runs in average O(1) time.
     */
    inout(cursor) elemAt(const(V) v) inout
    {
        auto pos = _hash.find(v);
        return inout(cursor)(pos, pos is _hash.end);
    }

    static if(doUnittest) unittest
    {
        auto hs = new HashSet;
        hs.add([1, 2, 3, 4, 5]);
        assert(hs.elemAt(6).empty);
    }

    /**
     * Returns true if the given value exists in the collection.
     *
     * Runs in average O(1) time.
     */
    bool contains(const(V) v) const
    {
        return !elemAt(v).empty;
    }

    static if(doUnittest) unittest
    {
        auto hs = new HashSet;
        hs.add([1, 2, 3, 4, 5]);
        assert(hs.contains(3));
        hs.remove(3);
        assert(!hs.contains(3));
    }


    /**
     * Removes the values in elems if they are present in the set.
     *
     * Runs on average in O(m) time where m is the length of elems.
     */
    HashSet remove(V[] elems...)
    {
        foreach(v; elems)
            remove(elemAt(v));
        return this;
    }

    static if(doUnittest) unittest
    {
        auto hs = new HashSet;
        hs.add([1, 2, 3, 4, 5]);
        hs.remove(1);
        assert(hs.arrayEqual([2, 3, 4, 5]));
        hs.remove(10);
        assert(hs.arrayEqual([2, 3, 4, 5]));
        hs.remove(4,2);
        assert(hs.arrayEqual([3, 5]));
    }

    /**
     * Remove all values that match the given iterator.
     */
    HashSet remove(Iterator!(V) it)
    {
        foreach(v; it)
            remove(v);
        return this;
    }

    static if(doUnittest) unittest
    {
        auto hs = new HashSet;
        hs.add([0, 1, 2, 3, 4, 5]);
        auto ai = new ArrayIterator!V([0, 2, 4, 6, 8]);
        hs.remove(ai);
        assert(hs.arrayEqual([1, 3, 5]));
        ai = new ArrayIterator!V([1, 3]);
        hs.remove(ai);
        assert(hs.arrayEqual([5]));
    }

    /**
     * Adds all the elements from the iterator to the set.
     *
     * Runs on average in O(1) + O(m) time, where m is the number of elements
     * in the iterator.
     *
     * Returns this.
     */
    HashSet add(Iterator!(V) it)
    {
        foreach(v; it)
            _hash.add(v);
        return this;
    }

    /**
     * Adds all the elements from elems to the set.
     *
     * Runs on average in O(1) + O(m) time, where m is the elems length.
     *
     * Returns this.
     */
    HashSet add(V[] elems...)
    {
        foreach(v; elems)
            _hash.add(v);
        return this;
    }

    static if(doUnittest) unittest
    {
        // add single element
        auto hs = new HashSet;
        hs.add(1).add(2);
        assert(hs.length == 2);
        assert(hs.arrayEqual([1, 2]));

        // add other collection
        // need to add duplicate, adding self is not allowed.
        auto hs2 = hs.dup();
        hs2.add(3);
        assert(trackLength(hs).add(hs2).delta == 1);
        hs.add(hs.dup());
        bool caughtexception = false;
        try
        {
            hs.add(hs);
        }
        catch(Exception)
        {
            caughtexception = true;
        }
        // should always be able to add self
        assert(!caughtexception);

        assert(hs.arrayEqual([1, 2, 3]));

        // add array
        hs.clear();
        hs.add([1, 2, 3, 4, 5]);
        // doesn't work, literals are interpreted as int
        //assert(trackLength(hs).add(3, 4, 5, 6, 7).delta == 2);
        hs.add(3, 4, 5, 6, 7);
        assert(hs.arrayEqual([1, 2, 3, 4, 5, 6, 7]));
    }

    /**
     * Remove all the values from the set that are not in the given subset
     *
     * returns this.
     */
    HashSet intersect(Iterator!(V) subset)
    {
        //
        // intersection is more difficult than removal, because we do not have
        // insight into the implementation details.  Therefore, make the
        // implementation do it.
        //
        _hash.intersect(subset);
        return this;
    }

    HashSet intersect(V[] subset...)
    {
        scope ai = new ArrayIterator!V(subset);
        _hash.intersect(ai);
        return this;
    }


    static if(doUnittest) unittest
    {
        auto hs = new HashSet;
        hs.add([0, 1, 2, 3, 4, 5]);
        auto ai = new ArrayIterator!V([0, 2, 4, 6, 8]);
        assert(trackLength(hs).intersect(ai).delta == -3);
        assert(hs.arrayEqual([0, 2, 4]));
        hs.intersect(0,4,8);
        assert(hs.arrayEqual([0, 4]));
    }

    /**
     * duplicate this hash set
     */
    HashSet dup()
    {
        return new HashSet(_hash);
    }

    /**
     * compare two sets for equality
     */
    override bool opEquals(Object o)
    {
        if(o !is null)
        {
            auto s = cast(Set!(V))o;
            if(s !is null && s.length == length)
            {
                foreach(elem; s)
                {
                    if(!contains(elem))
                        return false;
                }

                //
                // equal
                //
                return true;
            }
        }
        //
        // no comparison possible.
        //
        return false;
    }

    static if(doUnittest) unittest
    {
        auto hs = new HashSet;
        hs.add([1, 2, 3, 4, 5]);
        assert(hs == hs.dup());
    }

    /**
     * get the most convenient element in the set.  This is the element that
     * would be iterated first.  Therefore, calling remove(get()) is
     * guaranteed to be less than an O(n) operation.
     */
    inout(V) get() inout
    {
        return begin.front;
    }

    static if(doUnittest) unittest
    {
        auto hs = new HashSet;
        hs.add([1, 2, 3, 4, 5]);
        assert(!std.algorithm.find([1, 2, 3, 4, 5], hs.get()).empty);
    }

    /**
     * Remove the most convenient element from the set, and return its value.
     * This is equivalent to remove(get()), except that only one lookup is
     * performed.
     */
    V take()
    {
        auto c = begin;
        auto retval = c.front;
        remove(c);
        return retval;
    }

    static if(doUnittest) unittest
    {
        auto hs = new HashSet;
        V[] aa = [1, 2, 3, 4, 5];
        hs.add(aa);
        auto x = hs.take();
        assert(!std.algorithm.find([1, 2, 3, 4, 5], x).empty);
        // remove x from the original array, and check for equality
        assert(hs.arrayEqual(std.algorithm.partition!((V a) {return a == x;})(aa)));
    }
}

unittest
{
    // declare the Link list types that should be unit tested.
    HashSet!ubyte  hs1;
    HashSet!byte   hs2;
    HashSet!ushort hs3;
    HashSet!short  hs4;
    HashSet!uint   hs5;
    HashSet!int    hs6;
    HashSet!ulong  hs7;
    HashSet!long   hs8;

    // ensure that reference types can be used
    HashSet!(uint*) hs9;
    interface I {}
    class C : I {}
    HashSet!C hs10;
    HashSet!I hs11;
}
