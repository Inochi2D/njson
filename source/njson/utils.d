/*
    Various utilities

    Copyright © 2023, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module njson.utils;
import dplug.core;


class NJsonException : Exception {
@nogc:
public:

    this(string msg, string file = __FILE__, size_t line = __LINE__) pure nothrow @nogc @safe {
        super(msg, file, line);
    }
}

/**
    njson enforce
*/
void njEnforce(T, Ex=NJsonException)(T v, string ex) if (is (Ex : Throwable)) {
    if (!v) {
        throw mallocNew!Ex(ex);
    }
}

/**
    Returns a string which should be freed with reallocBuffer(0)
*/
string njFmt(T...)(const(char)* input, T fmt) {
    import core.stdc.stdio : snprintf;
    char[] buf;
    buf.reallocBuffer(50);

    int len = snprintf(buf.ptr, buf.length, input, fmt);
    if (len > 50) {
        buf.reallocBuffer(len);
        len = snprintf(buf.ptr, buf.length, input, fmt);
    }

    return cast(string)buf[0..len];
}