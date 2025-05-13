# brotli.zig

[brotli](https://github.com/google/brotli) packaged for zig 0.14.0

## Usage

`build.zig.zon`:

```sh
zig fetch --save git+https://github.com/0x546F6D/brotli.zig
```

`build.zig`:

```zig
const brotli_mod = b.addModule("brotli", .{
    .root_source_file = b.path("src/root.zig"),
});

const brotli_c = b.dependency("brotli_build", .{
    .target = target,
    .optimize = optimize,
});

brotli_mod.linkLibrary(brotli_c.artifact("brotli_lib"));
brotli_mod.addImport("brotli_c_api", brotli_c.module("c_api"));

exe.root_module.addImport("brotli", brotli_mod);
```

`root.zig`:

```zig
pub const c = @import("brotli_c_api");
```

## Example with minimal Zig Bindings

As an example, the following repo uses brotli.zig to provides minimal Zig bindings around BrotliEncoderCompress() and BrotliDecoderDecompress():

- [zig-brotli](https://github.com/0x546F6D/zig-brotli)
