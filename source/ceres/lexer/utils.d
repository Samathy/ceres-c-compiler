module ceres.lexer.utils;

version (unittest)
{
    import blerp.blerp;

    static this()
    {
        runTests!(__MODULE__);
    }
}

import blerp.blerp : BlerpTest;

bool isNewLine(char character)
{
    import std.uni : lineSep, paraSep, nelSep;

    if (character == lineSep || character == paraSep || character == nelSep
            || character == 0x0a || character == 0x00)
        return true;
    else if (character == '\n' || character == '\r')
        return true;
    else
        return false;
}

@BlerpTest("test_isNewLine") unittest
{
    assert(isNewLine('|') == false, "| is being counted as a newline");
    assert(isNewLine('\n') == true, "\\n is not being counted as a new line");
    assert(isNewLine(0x0a) == true, "0x0a is not being counted as a new line");
}

/** 
  * Generate a compile-time assotiative array of class names, to 
  * object factories which generate a new object of that type when called
  *
  */
template getTypes(T, string mod, int no_args, constructorArgs...)
{
    static assert(constructorArgs.length == no_args);

    /** In order to support both classes with constructors that take arguments, and constructors that don't take arguments,
      * We have to define two variants of the getTypes function.
      * The first, supports constructors taking 1 or more arguments, which must be specified in the 'constructorArgs param'
      * The second, supports constructors taking 0 arguments.
      * It is not possible to have subclasses with constructors with signatures that differ from that of the super type.
      */

    static if (no_args)
    {
        static T function(constructorArgs...)[string] getTypes()
        {
            assert(__ctfe);
            /**
         * Get all 'members' of this file.
         * That is functions, classes, structs, global data, everything
         **/
            mixin("import " ~ mod ~ ";");
            const static string[] members = [__traits(allMembers, mixin(mod))];

            // Make the assotiative array.
            T function(constructorArgs...)[string] types;

            // Loop over each 'member'
            static foreach (m; members)
            {
                //If its something that is a specialization of T ( i.e a subclass )
                static if (is(mixin(m) : T)) // If its a class
                {
                        /** Add it too the array by name, 
                  with a function which generates an object of that type as the value
                 **/
                        types[m] = makeObjectFactory!(mixin(m));
                    }
            }

            return types;
        }
    }
    else
    {
        static T function()[string] getTypes()
        {
            assert(__ctfe);
            /**
         * Get all 'members' of this file.
         * That is functions, classes, structs, global data, everything
         **/
            mixin("import " ~ mod ~ ";");
            const static string[] members = [__traits(allMembers, mixin(mod))];

            // Make the assotiative array.
            T function()[string] types;

            // Loop over each 'member'
            static foreach (m; members)
            {
                //If its something that is a specialization of T ( i.e a subclass )
                static if (is(mixin(m) : T)) // If its a class
                {
                        /** Add it too the array by name, 
                  with a function which generates an object of that type as the value
                 **/
                        types[m] = makeObjectFactory!(mixin(m));
                    }
            }

            return types;
        }
    }

    /**
      * Take a type, and return a function which, when called, creates an object of that type.
      */
    template makeObjectFactory(factoryType)
    {
        static if (constructorArgs.length)
        {
            T function(constructorArgs...) makeObjectFactory()
            {
                return function(constructorArgs...) {
                    return new factoryType(constructorArgs);
                };
            }
        }
        else
        {
            T function() makeObjectFactory()
            {
                return function() { return new factoryType(); };
            }
        }
    }
}
