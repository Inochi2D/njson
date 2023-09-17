/*
    JSON Value

    Copyright © 2023, Inochi2D Project
    Distributed under the 2-Clause BSD License, see LICENSE file.
    
    Authors: Luna Nielsen
*/
module njson.jvalue;
import njson.utils;
import dplug.core;
import std.traits;

/**
    A JSON Type
*/
enum JType {
    number_,
    string_,
    boolean_,
    array_,
    object_,
    null_
}

private {
    struct JValueStore {
        JType type;
        union {
            char[] str_;
            double num_;
            bool bool_;
            Vec!(JValue) array_;
            Map!(string, JValue) object_;
            void* null_;
        }

        size_t ref_ = 1;
    }
}

/**
    A JSON Value
*/
struct JValue {
@nogc nothrow:
private:
    JValueStore* store;
    alias store this;

    void freeContents() {
        switch(type) {
            default:
                // nothing to free other than self.
                break;

            case JType.string_:
                freeSlice(this.str_);
                break;
            
            case JType.array_:
                destroyNoGC(this.array_);
                break;

            case JType.object_:
                if (!this.object_.empty) {
                    this.object_.clearContents();
                }
                break;
        }
        this.null_ = null;
        this.type = JType.null_;
    }

public:
    ~this() {
        if (store) {
            store.ref_--;

            if (store.ref_ == 0) {
                this.freeContents();
                destroyFree(store);
            }
        }
    }

    this(this) { if(store) store.ref_++; }

    /**
        Creates a JSON string from a D string

        String value is copied out.
    */
    this(string str_) {
        this.store = mallocNew!JValueStore;

        this.type = JType.string_;
        this.str_.reallocBuffer(str_.length);
        this.str_[0..$] = str_[0..$];
    }

    /**
        Creates a JSON string from a null-terminated C string
        
        String value is copied out.
    */
    this(const(char)* str_) {
        import core.stdc.string : strlen;

        this.store = mallocNew!JValueStore;
        this.type = JType.string_;
        size_t slen = strlen(str_);
        this.str_.reallocBuffer(slen);
        this.str_[0..slen] = str_[0..slen];
    }

    /**
        Creates a JSON number from a numeric value
    
        Value will be cast to a double.
    */
    this(T)(T num_) if (isNumeric!T) {
        this.store = mallocNew!JValueStore;

        this.type = JType.number_;
        this.num_ = cast(double)num_;
    }

    /**
        Creates a JSON boolean from a numeric value
    */
    this(bool bool_) {
        this.store = mallocNew!JValueStore;

        this.type = JType.boolean_;
        this.bool_ = bool_;
    }

    /**
        Gets the numeric value in this JValue

        Returns 0 if this JValue is not a number
    */
    T get(T)() if(isNumeric!T) {
        if (type == JType.number_) {
            return cast(T)this.num_;
        }
        return 0;
    }

    /**
        Gets the boolean value in this JValue

        Returns false if this JValue is not a boolean
    */
    T get(T)() if (is(T == bool)) {
        if (type == JType.boolean_) {
            return this.bool_;
        }
        return false;
    }

    /**
        Gets the string value in this JValue

        Returns null if this JValue is not a string
    */
    T get(T)() if (is(T : string)) {
        if (type == JType.string_) {
            return cast(T)this.str_;
        }
        return null;
    }

    /**
        Indexes the JValue object
    */
    JValue* opIndex(T)(T key) {
        static if (is(T : string)) {
            if (type == JType.object_) {
                
                // Handle key not being present
                if (!this.object_.contains(key)) 
                    return null;
                
                return &this.object_[key];
            }
        } else static if (isIntegral!T) {
            if (type == JType.array_) {
                
                // Handle out of bounds indexing
                if (key >= this.array_.length())
                    return null;
                
                return &this.array_[key];
            }
        }
        return null;
    }
    
    /**
        Allows assigning a value in the JValue object
    */
    void opIndexAssign(U)(U value, string key) {
        if (type == JType.object_) {
            static if (is(U : JValue)) {
                this.object_.insert(key, value);
            } else {
                this.object_.insert(key, JValue(value));
            }
        }
    }
    
    /**
        Allows assigning a value in the JValue array
    */
    void opIndexAssign(U)(U value, size_t key) {
        if (type == JType.array_) {

            // Handle out of bounds indexing
            if (key >= this.array_.length())
                return;
            
            // Handle U value type
            static if (is(U : JValue)) {
                this.array_[key] = value;
            } else {
                this.array_[key] = value.toJValue;
            }
        }
    }

    /**
        Allows adding elements to this JValue array

        Does nothing if this is not an array.
    */
    auto opOpAssign(string op = "~=", T)(T value) {
        if (type == JType.array_) {
            static if (is(T : JValue)) {
                this.array_.pushBack(value);
            } else {
                this.array_.pushBack(JValue(value));
            }
        }
        return this;
    }

    /**
        Removes the specified key

        Returns whether removal took place
    */
    bool remove(string name) {
        if (type == JType.object_) {
            return this.object_.remove(name);
        }
        return false;
    }

    /**
        Removes the specified index

        Returns whether removal took place
    */
    bool remove(size_t index) {
        if (type == JType.array_) {
            
            // Handle case of past-end-indexing
            if (index >= this.array_.length) 
                return false;

            this.array_.removeAndShiftRestOfArray(index);
            return true;
        }
        return false;
    }

    /**
        Frees contents of this JValue

        This will deallocate the memory of the value,
        if this is an object or array then every sub-object will be invalidated as well.
    */
    void nullify() {
        this.freeContents();
    }

    /**
        Gets the type of this JValue
    */
    JType getType() {
        return type;
    }

    /**
        Creates a null value

        Free with destroyFree
    */
    static JValue newNull() {
        JValue v;
        v.store = mallocNew!JValueStore;
        v.type = JType.null_;
        v.null_ = null;
        return v;
    }

    /**
        Creates a new array

        Free with destroyFree
    */
    static JValue newArray() {
        JValue v;
        v.store = mallocNew!JValueStore;
        v.store.type = JType.array_;
        v.store.array_ = makeVec!(JValue)();
        return v;
    }

    /**
        Creates a new object

        Free with destroyFree
    */
    static JValue newObject() {
        JValue v;
        v.store = mallocNew!JValueStore;
        v.store.type = JType.object_;
        v.store.object_ = makeMap!(string, JValue)();
        return v;
    }

    /**
        Returns a newly allocated string that can be freed with freeSlice
    */
    string toNGCString() {
        switch(type) {
            case JType.string_:
                string rs = cast(string)mallocDup(str_);
                return rs;

            case JType.boolean_:
                string rs = bool_ ? "true" : "false";
                return cast(string)mallocDup(rs);

            case JType.number_:
                return njFmt("%g", num_);
            
            case JType.null_:
                string rs = "null";
                return cast(string)mallocDup(rs);
            
            case JType.array_:
                string rs = "<array>";
                return cast(string)mallocDup(rs);
            
            case JType.object_:
                string rs = "<object>";
                return cast(string)mallocDup(rs);
            
            default:
                string rs = "undefined"; 
                return cast(string)mallocDup(rs);
        }
    }
}

/**
    Wraps a D value to a JValue
*/
JValue toJValue(T)(T input) {
    return JValue(input);
}

@("JValue (toNGCString)")
unittest {
    JValue v = JValue(42.4);
    string s = v.toNGCString();
    assert(s == "42.4");
    s.freeSlice();
    v.nullify();
    
    v = JValue("Hello, world!");
    s = v.toNGCString();
    assert(s == "Hello, world!");
    s.freeSlice();
    v.nullify();
    
    v = JValue(true);
    s = v.toNGCString();
    assert(s == "true");
    s.freeSlice();
    v.nullify();
    
    v = JValue.newArray;
    s = v.toNGCString();
    assert(s == "<array>");
    s.freeSlice();
    v.nullify();
    
    v = JValue.newObject;
    s = v.toNGCString();
    assert(s == "<object>");
    s.freeSlice();
    v.nullify();
    
    v.nullify();
    s = v.toNGCString();
    assert(s == "null");
    s.freeSlice();
    v.nullify();
}

@("JValue (Value Test)")
unittest {
    import std.stdio : writeln;
    JValue num_ = JValue(42.4);
    JValue str_ = JValue("Hello, world!");
    JValue bool_ = JValue(true);
    JValue null_ = JValue.newNull();

    assert(num_.get!double == 42.4);
    assert(str_.get!string == "Hello, world!");
    assert(bool_.get!bool == true);
    assert(null_.getType() == JType.null_);
}

@("JValue (Object add)")
unittest {
    import std.stdio : writeln;
    JValue nval_ = JValue.newObject();  

    // Test adding to JValue
    nval_["a"] = "Hello, world!";
    nval_["b"] = 42;

    assert(nval_["a"].get!string == "Hello, world!");
    assert(nval_["b"].get!int == 42);
}

@("JValue (Object remove)")
unittest {
    JValue nval_ = JValue.newObject();
    
    // Test adding to JValue
    nval_["a"] = toJValue("Hello, world!");
    nval_["b"] = toJValue(42);

    nval_.remove("a");
    nval_.remove("b");

    assert(nval_["a"] == null);
    assert(nval_["b"] == null);

}

@("JValue (Array append)")
unittest {
    JValue nval_ = JValue.newArray();
    nval_ ~= 42;

    assert(nval_[0].get!int == 42);
}