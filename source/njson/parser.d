/*
    JSON Parser

    Copyright © 2023, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module njson.parser;
import njson.jvalue;
import njson.utils;
import std.uni : isWhite, isNumber;
import dplug.core;

@nogc:
private:

/**
    njson enforce
*/
void njEnforce(T)(T v, size_t line, size_t c, string ex) {
    if (!v) {
        throw mallocNew!NJsonParseException(ex, line, c);
    }
}

struct NJParseContext {
@nogc nothrow:
    string str;
    size_t idx;

    size_t line;
    size_t c;

    void skipWhitespace() {
        while(isWhite(str[idx])) {
            if (str[idx] == '\n') {
                line++;
                c = 0;
            }
            idx++;
        }
    }

    char peekNext(size_t offset=1) {
        return str[idx+offset];
    }

    string peekNextRange(size_t offset) {
        return str[idx..idx+offset < str.length ? idx+offset : str.length];
    }

    JType determineType() {
        char nextChar = peekNext();

        switch(nextChar) {
            // String
            case '"':
                // Number special case
                // This is for compatibility with Inochi2D.
                if (peekNextRange(5) == "\"nan\"") return JType.number_;
                else if (peekNextRange(6) == "\"-nan\"") return JType.number_;

                // Otherwise it's a string
                return JType.string_;

            // Negative number
            case '-':
                return JType.number_;

            case '{':
                return JType.object_;
            
            case '[':
                return JType.array_;

            default:
                // Number
                if (isNumber(nextChar)) return JType.number_;

                // Boolean
                if (peekNextRange(5) == "false") return JType.boolean_;
                if (peekNextRange(4) == "true") return JType.boolean_;
                if (peekNextRange(4) == "null") return JType.null_;

                return JType.null_;
        }
    }
}

string njParseString(ref NJParseContext ctx) {

    // Skip whitespace
    ctx.skipWhitespace();

    njEnforce(ctx.str[ctx.idx++] == '"', ctx.line, ctx.c, "Expected '\"'.");
    
    size_t startIdx = ctx.idx++;
    while(ctx.str[ctx.idx] != '"') {
        ctx.idx++;

        njEnforce(ctx.idx < ctx.str.length, ctx.line, ctx.c, "Unexpected EOF");
    }

    return ctx.str[startIdx..ctx.idx++];
}

void njParseObject(ref NJParseContext ctx, ref JValue value) {

    // Skip whitespace
    ctx.skipWhitespace();

    // Ensure we have an object-open
    njEnforce(ctx.str[ctx.idx++] == '{', ctx.line, ctx.c, "Expected '{'.");

    // Iterate on object open
    do {
        njEnforce(ctx.idx < ctx.str.length, ctx.line, ctx.c, "Unexpected EOF");

        ctx.skipWhitespace();

        string key = njParseString(ctx);
        
        njEnforce(ctx.str[ctx.idx++] == ':', ctx.line, ctx.c, "Expected ':'.");

        ctx.skipWhitespace();
    } while(ctx.str[ctx.idx] != '}');

    // Skip }
    ctx.idx++;
}

void njParseArray(ref NJParseContext ctx, ref JValue value) {

    // Skip whitespace
    ctx.skipWhitespace();

    // Ensure we have an object-open
    njEnforce(ctx.str[ctx.idx++] == '[', ctx.line, ctx.c, "Expected '{'.");

    // Iterate on object open
    do {
        njEnforce(ctx.idx < ctx.str.length, ctx.line, ctx.c, "Unexpected EOF");
        ctx.skipWhitespace();



        ctx.skipWhitespace();
        if (ctx.peekNext(0) == ',') {
            ctx.idx++;
            continue;
        } else if (ctx.peekNext(0) == ']') {
            ctx.idx++;
            break;
        } else {
            throw mallocNew!NJsonParseException("Expected ',' or ']'!", ctx.line, ctx.c);
        }
        
    } while(true);

    // Skip }
    ctx.idx++;
}

void njParseValue(ref NJParseContext ctx, ref JValue value) {
    switch(ctx.determineType()) {
        case JType.array_:
            njParseObject(ctx, value);
            break;
        case JType.object_:
            njParseObject(ctx, value);
            break;
        default: break;
    }
}

public:


class NJsonParseException : Exception {
@nogc:
public:

    /**
        Line which error the occured on
    */
    size_t line;

    /**
        Character index which the error occured on
    */
    size_t charIndex;

    this(string msg, size_t line, size_t charIndex) pure nothrow @nogc @safe {
        super(msg);
        this.line = line;
        this.charIndex = charIndex;
    }
}

/**
    Parses the passed JSON from a UTF-8 encoded string.
*/
JValue parseJson(string json) {
    JValue value;
    NJParseContext ctx;
    ctx.str = json;

    njParseValue(ctx, value);

    return value;
}
