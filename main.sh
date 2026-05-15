#!/usr/bin/env bash
set -e
export PATH="$HOME/.local/bin:$PATH"
export LD_LIBRARY_PATH="/nix/store/xb4h083j02mr2ix7pgj7iawxh2hk100l-postgresql-15.7-lib/lib:/nix/store/8b9bdqwjxahgyl8yns92cva6b6j8kirz-hiredis-1.2.0/lib:/nix/store/gp504m4dvw5k2pdx6pccf1km79fkcwgf-openssl-3.0.13/lib:/nix/store/lv6nackqis28gg7l2ic43f6nk52hb39g-zlib-1.3.1/lib:$LD_LIBRARY_PATH"

echo "Building search-platform with Zig 0.14.0..."
zig build 2>&1

echo "Build complete. Starting server..."
exec ./zig-out/bin/search-platform
