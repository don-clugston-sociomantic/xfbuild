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
module dcollections.util;

public import dcollections.model.Iterator;
private import std.traits;

/**
 * This iterator transforms every element from another iterator using a
 * transformation function.
 */
final class TransformIterator(V, U=V) : Iterator!(V)
{
    private Iterator!(U) _src;
    private void delegate(ref U, ref V) _dg;
    private void function(ref U, ref V) _fn;

    /**
     * Construct a transform iterator using a transform delegate.
     *
     * The transform function transforms a type U object into a type V object.
     */
    this(Iterator!(U) source, void delegate(ref U, ref V) dg)
    {
        _src = source;
        _dg = dg;
    }

    /**
     * Construct a transform iterator using a transform function pointer.
     *
     * The transform function transforms a type U object into a type V object.
     */
    this(Iterator!(U) source, void function(ref U, ref V) fn)
    {
        _src = source;
        _fn = fn;
    }

    /**
     * Returns the length that the source provides.
     */
    @property size_t length() const
    {
        return _src.length;
    }

    /**
     * Iterate through the source iterator, working with temporary copies of a
     * transformed V element.
     */
    int opApply(scope int delegate(ref V v) dg)
    {
        int privateDG(ref U u)
        {
            V v;
            _dg(u, v);
            return dg(v);
        }

        int privateFN(ref U u)
        {
            V v;
            _fn(u, v);
            return dg(v);
        }

        if(_dg is null)
            return _src.opApply(&privateFN);
        else
            return _src.opApply(&privateDG);
    }
}

/**
 * Transform for a keyed iterator
 */
final class TransformKeyedIterator(K, V, J=K, U=V) : KeyedIterator!(K, V)
{
    private KeyedIterator!(J, U) _src;
    private void delegate(ref J, ref U, ref K, ref V) _dg;
    private void function(ref J, ref U, ref K, ref V) _fn;

    /**
     * Construct a transform iterator using a transform delegate.
     *
     * The transform function transforms a J, U pair into a K, V pair.
     */
    this(KeyedIterator!(J, U) source, void delegate(ref J, ref U, ref K, ref V) dg)
    {
        _src = source;
        _dg = dg;
    }

    /**
     * Construct a transform iterator using a transform function pointer.
     *
     * The transform function transforms a J, U pair into a K, V pair.
     */
    this(KeyedIterator!(J, U) source, void function(ref J, ref U, ref K, ref V) fn)
    {
        _src = source;
        _fn = fn;
    }

    /**
     * Returns the length that the source provides.
     */
    @property size_t length() const
    {
        return _src.length;
    }

    /**
     * Iterate through the source iterator, working with temporary copies of a
     * transformed V element.  Note that K can be ignored if this is the only
     * use for the iterator.
     */
    int opApply(scope int delegate(ref V v) dg)
    {
        int privateDG(ref J j, ref U u)
        {
            K k;
            V v;
            _dg(j, u, k, v);
            return dg(v);
        }

        int privateFN(ref J j, ref U u)
        {
            K k;
            V v;
            _fn(j, u, k, v);
            return dg(v);
        }

        if(_dg is null)
            return _src.opApply(&privateFN);
        else
            return _src.opApply(&privateDG);
    }

    /**
     * Iterate through the source iterator, working with temporary copies of a
     * transformed K,V pair.
     */
    int opApply(scope int delegate(ref K k, ref V v) dg)
    {
        int privateDG(ref J j, ref U u)
        {
            K k;
            V v;
            _dg(j, u, k, v);
            return dg(k, v);
        }

        int privateFN(ref J j, ref U u)
        {
            K k;
            V v;
            _fn(j, u, k, v);
            return dg(k, v);
        }

        if(_dg is null)
            return _src.opApply(&privateFN);
        else
            return _src.opApply(&privateDG);
    }
}

/**
 * A Chain iterator chains several iterators together.
 */
final class ChainIterator(V) : Iterator!(V)
{
    private Iterator!(V)[] _chain;
    private bool _supLength;

    /**
     * Constructor.  Pass in the iterators you wish to chain together in the
     * order you wish them to be chained.
     *
     * If all of the iterators support length, then this iterator supports
     * length.  If one doesn't, then the length is not supported.
     */
    this(Iterator!(V)[] chain ...)
    {
        _chain = chain.dup;
        _supLength = true;
        foreach(it; _chain)
            if(it.length == ~0)
            {
                _supLength = false;
                break;
            }
    }

    /**
     * Returns the sum of all the iterator lengths in the chain.
     *
     * returns NO_LENGTH_SUPPORT if a single iterator in the chain does not support
     * length
     */
    @property size_t length() const
    {
        if(_supLength)
        {
            size_t result = 0;
            foreach(it; _chain)
                result += it.length;
            return result;
        }
        return NO_LENGTH_SUPPORT;
    }

    /**
     * Iterate through the chain of iterators.
     */
    int opApply(scope int delegate(ref V v) dg)
    {
        int result = 0;
        foreach(it; _chain)
        {
            if((result = it.opApply(dg)) != 0)
                break;
        }
        return result;
    }
}

/**
 * A Chain iterator chains several iterators together.
 */
final class ChainKeyedIterator(K, V) : KeyedIterator!(K, V)
{
    private KeyedIterator!(K, V)[] _chain;
    private bool _supLength;

    /**
     * Constructor.  Pass in the iterators you wish to chain together in the
     * order you wish them to be chained.
     *
     * If all of the iterators support length, then this iterator supports
     * length.  If one doesn't, then the length is not supported.
     */
    this(KeyedIterator!(K, V)[] chain ...)
    {
        _chain = chain.dup;
        _supLength = true;
        foreach(it; _chain)
            if(it.length == NO_LENGTH_SUPPORT)
            {
                _supLength = false;
                break;
            }
    }

    /**
     * Returns the sum of all the iterator lengths in the chain.
     *
     * returns NO_LENGTH_SUPPORT if any iterators in the chain return -1 for length
     */
    @property size_t length() const
    {
        if(_supLength)
        {
            size_t result = 0;
            foreach(it; _chain)
                result += it.length;
            return result;
        }
        return NO_LENGTH_SUPPORT;
    }

    /**
     * Iterate through the chain of iterators using values only.
     */
    int opApply(scope int delegate(ref V v) dg)
    {
        int result = 0;
        foreach(it; _chain)
        {
            if((result = it.opApply(dg)) != 0)
                break;
        }
        return result;
    }

    /**
     * Iterate through the chain of iterators using keys and values.
     */
    int opApply(scope int delegate(ref K, ref V) dg)
    {
        int result = 0;
        foreach(it; _chain)
        {
            if((result = it.opApply(dg)) != 0)
                break;
        }
        return result;
    }
}

/**
 * A Filter iterator filters out unwanted elements based on a function or
 * delegate.
 */
final class FilterIterator(V) : Iterator!(V)
{
    private Iterator!(V) _src;
    private bool delegate(ref V) _dg;
    private bool function(ref V) _fn;

    /**
     * Construct a filter iterator with the given delegate deciding whether an
     * element will be iterated or not.
     *
     * The delegate should return true for elements that should be iterated.
     */
    this(Iterator!(V) source, bool delegate(ref V) dg)
    {
        _src = source;
        _dg = dg;
    }

    /**
     * Construct a filter iterator with the given function deciding whether an
     * element will be iterated or not.
     *
     * the function should return true for elements that should be iterated.
     */
    this(Iterator!(V) source, bool function(ref V) fn)
    {
        _src = source;
        _fn = fn;
    }

    /**
     * Returns NO_LENGTH_SUPPORT
     */
    @property size_t length() const
    {
        //
        // cannot know what the filter delegate/function will decide.
        //
        return NO_LENGTH_SUPPORT;
    }

    /**
     * Iterate through the source iterator, only accepting elements where the
     * delegate/function returns true.
     */
    int opApply(scope int delegate(ref V v) dg)
    {
        int privateDG(ref V v)
        {
            if(_dg(v))
                return dg(v);
            return 0;
        }

        int privateFN(ref V v)
        {
            if(_fn(v))
                return dg(v);
            return 0;
        }

        if(_dg is null)
            return _src.opApply(&privateFN);
        else
            return _src.opApply(&privateDG);
    }
}

/**
 * A Filter iterator filters out unwanted elements based on a function or
 * delegate.  This version filters on a keyed iterator.
 */
final class FilterKeyedIterator(K, V) : KeyedIterator!(K, V)
{
    private KeyedIterator!(K, V) _src;
    private bool delegate(ref K, ref V) _dg;
    private bool function(ref K, ref V) _fn;

    /**
     * Construct a filter iterator with the given delegate deciding whether a
     * key/value pair will be iterated or not.
     *
     * The delegate should return true for elements that should be iterated.
     */
    this(KeyedIterator!(K, V) source, bool delegate(ref K, ref V) dg)
    {
        _src = source;
        _dg = dg;
    }

    /**
     * Construct a filter iterator with the given function deciding whether a
     * key/value pair will be iterated or not.
     *
     * the function should return true for elements that should be iterated.
     */
    this(KeyedIterator!(K, V) source, bool function(ref K, ref V) fn)
    {
        _src = source;
        _fn = fn;
    }

    /**
     * Returns NO_LENGTH_SUPPORT
     */
    @property size_t length() const
    {
        //
        // cannot know what the filter delegate/function will decide.
        //
        return NO_LENGTH_SUPPORT;
    }

    /**
     * Iterate through the source iterator, only iterating elements where the
     * delegate/function returns true.
     */
    int opApply(scope int delegate(ref V v) dg)
    {
        int privateDG(ref K k, ref V v)
        {
            if(_dg(k, v))
                return dg(v);
            return 0;
        }

        int privateFN(ref K k, ref V v)
        {
            if(_fn(k, v))
                return dg(v);
            return 0;
        }

        if(_dg is null)
            return _src.opApply(&privateFN);
        else
            return _src.opApply(&privateDG);
    }

    /**
     * Iterate through the source iterator, only iterating elements where the
     * delegate/function returns true.
     */
    int opApply(scope int delegate(ref K k, ref V v) dg)
    {
        int privateDG(ref K k, ref V v)
        {
            if(_dg(k, v))
                return dg(k, v);
            return 0;
        }

        int privateFN(ref K k, ref V v)
        {
            if(_fn(k, v))
                return dg(k, v);
            return 0;
        }

        if(_dg is null)
            return _src.opApply(&privateFN);
        else
            return _src.opApply(&privateDG);
    }
}

/**
 * Simple iterator wrapper for an array.
 */
final class ArrayIterator(V) : Iterator!(V)
{
    private V[] _array;

    /**
     * Wrap a given array.  Note that this does not make a copy.
     */
    this(V[] array)
    {
        _array = array;
    }

    /**
     * Returns the array length
     */
    @property size_t length() const
    {
        return _array.length;
    }

    /**
     * Iterate over the array.
     */
    int opApply(scope int delegate(ref V) dg)
    {
        int retval = 0;
        foreach(ref x; _array)
            if((retval = dg(x)) != 0)
                break;
        return retval;
    }
}

/**
 * Wrapper iterator for an associative array
 */
final class AAIterator(K, V) : KeyedIterator!(K, V)
{
    private V[K] _array;

    /**
     * Construct an iterator wrapper for the given array
     */
    this(V[K] array)
    {
        _array = array;
    }

    /**
     * Returns the length of the wrapped AA
     */
    size_t length()
    {
        return _array.length;
    }

    /**
     * Iterate over the AA
     */
    int opApply(scope int delegate(ref K, ref V) dg)
    {
        int retval;
        foreach(k, ref v; _array)
            if((retval = dg(k, v)) != 0)
                break;
        return retval;
    }
}

/**
 * Function that converts an iterator to an array.
 *
 * More optimized for iterators that support a length.
 */
V[] toArray(V)(Iterator!(V) it)
{
    V[] result;
    auto len = it.length;
    if(len != NO_LENGTH_SUPPORT)
    {
        //
        // can optimize a bit
        //
        result.length = len;
        size_t i = 0;
        foreach(v; it)
            result[i++] = v;
    }
    else
    {
        foreach(v; it)
            result ~= v;
    }
    return result;
}

/**
 * Convert a keyed iterator to an associative array.
 */
V[K] toAA(K, V)(KeyedIterator!(K, V) it)
{
    V[K] result;
    foreach(k, v; it)
        result[k] = v;
    return result;
}

/**
 * LengthTracker is a structure which allows chain calling on dcollections class
 * functions, and then allows one to easily access the delta in length that
 * those functions caused.  Prior to this struct, support for getting the
 * affected length was given directly through the function calls, but this
 * drastically reduces the need for this, especially when most of the time, the
 * length affected is not needed.
 *
 * Intended to be used via trackLength function below
 */
struct LengthTracker(T)
{
    private T t;
    private size_t origlen;

    /**
     * Construct a LengthTracker given a container type
     */
    this(T t)
    {
        this.t = t;
        this.origlen = t.length;
    }

    /**
     * Dispatch any function calls to the given collection type.  Note, we only
     * care about chainable functions.  If you call something other than a
     * chainable function, it doesn't make any sense to use LengthTracker, so
     * this is a sanity check.
     *
     * Note, it is illegal to use a function that returns a different instance
     * than the one used to chain.  On non-release versions of the library,
     * this will result in an assert exception.
     */
    auto opDispatch(string fn, Args...)(Args args) if (is(typeof(mixin("t." ~ fn ~ "(args)")) == T))
    {
        auto x = mixin("t." ~ fn ~ "(args)");
        assert(x is t); // verify we are actually chaining
        return this;
    }

    /**
     * Get the difference in length from when the LengthTracker value was
     * created.
     */
    @property ptrdiff_t delta()
    {
        return t.length - origlen;
    }
}

/**
 * Use this function to chain function calls to a dcollections class when you
 * want to know the affected length in the same expression.
 *
 * ---------------
 * auto numAdded = trackLength(mycollection).add(1,2,3).add(myothercollection).delta;
 * ---------------
 */
LengthTracker!T trackLength(T)(T t)
{
    return LengthTracker!T(t);
}
