#import "Basic";
#import "Math";
#import "File";
#import "Hash_Table";
using Serializer :: #import,dir "../osor_serialization";



main :: ()
{
    set_my_print_format();

    simple_example();
    more_types_and_to_a_file();
    how_about_compile_time();
    replacing_type();
}



simple_example :: ()
{
    print_example_name("A simple example");

    Test :: struct { a : int; }

    //
    // Set up some simple data that we want to transform to an array of bytes
    //
    original_test : Test;
    original_test.a = 123;
    print("Original: %\n", original_test);

    //
    // This transform the data to an array of bytes that we can recover later.
    //
    // It allocates a single time with a single call to alloc() so you could use a
    // different allocator by changing context.allocator.
    //
    serialized_test := serialize(*original_test);

    //
    // Changing the original data here after serializing to
    // prove that the data isn't just pointing to the original variable
    //
    original_test.a = 456; 

    //
    // Now we take the array of bytes that we just generate it and transform
    // it back to a "Test".
    //
    // This obviously doesn't make much sense in a contrived example like this, but
    // you could take any data, serialize it to an array of bytes and store it to a file.
    //
    // Then you read back that file, load the contents and recover the original struct!
    //
    deserialized_test := deserialize(serialized_test, Test);
    print("Deserialized: %\n", <<deserialized_test);
    assert(deserialized_test.a == 123);
}



more_types_and_to_a_file :: ()
{
    print_example_name("More types, and to a file!");

    Test :: struct
    {
        a := 123123;
        b : []u8;
        c := "testoooooaaaaaaaaaaooooT";
        variant : A_Variant = xx 11223344;
        internal : []Internal_Test;
        d : [2]float32 = .[-1.0, 1.0];
        table : Table(u32, string);
    }

    A_Variant :: #type,distinct u64;

    Internal_Test :: struct
    {
        a : []u16;
        b : [3]string = .["hey", "these", "count"];
        c : [..]float64;
    }

    //
    // Here we create a "Test" with a bunch of types, so you can see
    // that things with dynamic sizes such as strings and arrays of things work
    // as you'd expect.
    //
    // Then we write that to a file 
    //
    {
        internal : [2]Internal_Test;
        defer array_reset(*internal[0].c);
        defer array_reset(*internal[1].c);
        internal[0].a = .[1, 2, 3, 123, 0xFF_FF];
        internal[0].b[2] = "sailor??? what???";
        internal[1].a = .[3, 3, 2, 1];
        internal[1].b[1] = "At this point I don't know what to write here";
        array_add(*internal[1].c, 123.123);
        array_add(*internal[1].c, 666.777);
        array_add(*internal[1].c, 888.777);

        test : Test;
        defer deinit(*test.table);
        test.b = .[75, 75, 75, 75, 75, 75, 75, 75, 76];
        test.c = "yo what's up?";
        test.internal.count = internal.count;
        test.internal.data  = internal.data;
        test.d[0] = 123.123;
        table_set(*test.table, 12, "a value on the table");
        table_set(*test.table, 123, "another value on the table");
        serialized_data := serialize(*test);

        success := write_entire_file("./serialized_data.bin", cast(string)serialized_data);
        assert(success);
    }

    //
    // This takes the serialized data in the array of bytes generated above
    // and deserializes it into what would be a copy of "test" that we set
    // up before.
    //
    {
        serialized_data := cast([]u8)read_entire_file("./serialized_data.bin");
        test := deserialize(serialized_data, Test);
        print("%\n", <<test);
        for test.table print("%, %\n", it_index, it);
    }
}



how_about_compile_time :: ()
{
    print_example_name("Serializing at compile-time and deserializing at runtime");
    Test :: struct
    {
        a : []int;
        b : string;
        c : Table(string, int);
    }

    //
    // Note how the data to be deserialized to be writable!
    //
    // Here we're making it a constant first, and then initializing
    // a variable that copies from the constant array. You can do it
    // in one step by doing data := #run -> []u8 { ... } but I'm making
    // it explicit here for clarity. 
    //
    SERIALIZED_DATA_AT_COMPILE_TIME :: #run -> []u8
    {
        test : Test;
        test.a = .[1,2,3,4,5];
        test.b = "how about dem stringz";
        table_set(*test.c, "how many croissants do we have?", 60345);
        return serialize(*test);
    };
    serialized_data_at_compile_time := SERIALIZED_DATA_AT_COMPILE_TIME;

    test := deserialize(serialized_data_at_compile_time, Test);
    print("%\n", <<test);
    for test.c print("%, %\n", it_index, it);
}



//
// If you have a type that you want to be serialized as a different set of data
// you can do it with a SERIALIZATION_REPLACEMENT. This basically will store the
// replacement type instead.
//
// To do the replacement it'll call the provided procedures serialization_replacement
// and deserialization_replacement, which need to transform back and forth from the two types.
//
// One example that I've used this for is for hashed-strings/string-ids on dev builds.
// Where instead of serializing only the hash, you serialize both the hash and the string
// that hashes to it. So when you deserialize the data later, you can see the original string
// on debug builds and keep track of it.
//
Original_Type :: struct
{
    data : float64;
    SERIALIZATION_REPLACEMENT :: Replacement_Type;
}
Replacement_Type :: struct
{
    data_compressed : u8;
    time_of_compression : Apollo_Time;
}
serialization_replacement :: (original : *Original_Type) -> Replacement_Type
{
    //
    // Note how this procedure gets called twice during serialization. This is because
    // the code goes throught the members twice. Once to see how much dynamic memory will
    // be required in total, then another time to do the copy after it has done the allocation.
    //
    print("Transforming the original data to the replacement type");
    replacement : Replacement_Type;
    replacement.data_compressed = cast(u8)floor(original.data * 255.0 + 0.5);
    replacement.time_of_compression = current_time_consensus();
    return replacement;
}
deserialization_replacement :: (replacement : *Replacement_Type) -> Original_Type
{
    //
    // And this will get called once during deserialization, so you could run any code in here, such
    // as putting stuff in your own global data structures, or god knows.
    //
    original : Original_Type;
    print("Deserializing data that was compressed on %\n", to_calendar(replacement.time_of_compression));
    original.data = replacement.data_compressed / 255.00;
    return original;
}

//
// You need to #poke_name the types and the replacement procedures into the module
// because otherwise it'll try to insert code that uses them, but since these are not
// in the scope of the module it doesn't know what the hell they are.
//
#poke_name Serializer Replacement_Type;
#poke_name Serializer serialization_replacement;
#poke_name Serializer deserialization_replacement;

replacing_type :: ()
{
    print_example_name("Serializing a type with a replacement");
    Test :: struct
    {
        og : Original_Type;
    }
    data := ifx true 
    {
        test : Test;
        test.og.data = 0.123;
        serialize(*test);
    };
    test := deserialize(data, Test);
    print("%\n", <<test);
}



#scope_file



print_example_name :: (name : string) #expand
{
    for 0..(8 + name.count)-1 print("#");
    print("\n### % ###\n", name);
    for 0..(8 + name.count)-1 print("#");
    print("\n");
    `defer print("\n\n\n");
}



set_my_print_format :: (c : *Context = null)
{
    if c == null then c = *context;

    // structs
    {
        using c.print_style.default_format_struct;
        draw_type_name = true;
        use_long_form_if_more_than_this_many_members = -1;
        separator_between_name_and_value    = " = ";
        short_form_separator_between_fields = ", ";
        long_form_separator_between_fields  = "; ";
        begin_string = "{";
        end_string   = "}";
        indentation_width = 4;
        use_newlines_if_long_form = true;
    }

    // arrays
    {
        using c.print_style.default_format_array;
        separator = ", ";
        begin_string = "[";
        end_string   = "]";
        printing_stopped_early_string = "...";
        draw_separator_after_last_element = false;
        stop_printing_after_this_many_elements = 16;
    }

    // floats
    {
        using c.print_style.default_format_float;
        zero_removal = .ONE_ZERO_AFTER_DECIMAL;
    }
}