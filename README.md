# :minidisc: A Serialization Module for Jai

A wee serialization module for the Jai programming language. You can check the code in [module.jai](module.jai) then a few examples of how to use them in [example.jai](example.jai).

## How To
You can call `serialize` to transform a data structure into a byte buffer (including stuff like arrays, strings, pointers and potentially other dynamically allocated stuff). This only allocates a single time to get a buffer big enough to fit all the data on your type + any variable size data. It can also use a given allocator, defaulting to the current `context.allocator`.
```
data : Data;
bytes := serialize(*data);
store_bytes_somewhere(bytes);
```
Then you can read back those bytes and transform them to a pointer of the original size by calling `deserialize`. This casts the bytes to a pointer of the type you serialized and resolves any dynamic data. No allocations happen at this stage, just some data fixup so everything points to where it should in memory.
```
bytes := read_bytes_from_somewhere();
data := deserialize(bytes, Data);
happily_use_the_data(data);
```

## Notes

Part of the purpose of this module was to explore how to do serialization/deserialization fast using the features that Jai offers that aren't in most languages. It makes extensive use of the type information that the language gives but also makes good use of compile-time code generation. For each type that the code will serialize/deserialize it will generate bespoke code to handle its members. The generated code is nice and fast but it's good to take into account that if this is overused it might make a dent in compile times and potentially code size, although I haven't experienced either in any significant way myself at the time of writing.

## License

I want people to be able to just use this without thinking about licensing, although give me a shout if you do use it and attribution is appreciated 😊. Replicating STB's (https://github.com/nothings/stb) licensing stuff where you can choose to use public domain or MIT.
