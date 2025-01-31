# brotli.zig

[brotli](https://github.com/google/brotli) packaged for zig (0.14.0-dev.2992)

## Usage

To build a zig wrapper around brotli:

`build.zig.zon`:

```sh
zig fetch --save git+https://github.com/0x546F6D/brotli.zig
```

`build.zig`:

```zig
const brotli_c = b.dependency("brotli.zig", .{
    .target = target,
    .optimize = optimize,
});
const brotli_mod = b.addModule("brotli", .{
    .root_source_file = b.path("src/brotli.zig"),
});
brotli_mod.linkLibrary(brotli_c.artifact("brotli_lib"));

exe.root_module.addImport("brotli", brotli_mod);
```

`brotli.zig`:

```zig
pub const br_c = @cImport({
    @cInclude("brotli/decode.h");
    @cInclude("brotli/encode.h");
    @cInclude("brotli/port.h");
    @cInclude("brotli/shared_dictionary.h");
    @cInclude("brotli/types.h");
});
```

## Example with minimal Zig Bindings

As an example, the following repo uses brotli.zig to provides minimal Zig bindings around BrotliEncoderCompress() and BrotliDecoderDecompress():

- [zig-brotli](https://github.com/0x546F6D/zig-brotli)
