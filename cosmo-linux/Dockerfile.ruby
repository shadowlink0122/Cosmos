# musl静的リンク Ruby 3.4 ビルド (Cosmo Linux用)
#
# ビルド:
#   docker build --platform linux/amd64 -f Dockerfile.ruby -t cosmo-ruby .
# 取得:
#   docker run --rm --platform linux/amd64 cosmo-ruby > rootfs/packages/ruby
#   chmod +x rootfs/packages/ruby
FROM alpine:3.20

# ビルドツール + 依存ライブラリ (静的リンク用)
RUN apk add --no-cache \
    build-base file wget autoconf bison \
    linux-headers \
    zlib-dev zlib-static \
    openssl-dev openssl-libs-static \
    readline-dev readline-static \
    yaml-dev yaml-static \
    ncurses-dev ncurses-static \
    libffi-dev

# Ruby 3.4.2 ソースからビルド (完全静的リンク)
# - テスト拡張を除外するために2段階ビルド
# - miniruby (静的) → フルruby (静的)
RUN wget https://cache.ruby-lang.org/pub/ruby/3.4/ruby-3.4.2.tar.gz && \
    tar xzf ruby-3.4.2.tar.gz && \
    cd ruby-3.4.2 && \
    LDFLAGS="-static" CFLAGS="-Os -DRUBY_EXPORT" \
    ./configure \
    --prefix=/usr \
    --disable-shared \
    --enable-static \
    --disable-install-doc \
    --disable-install-rdoc \
    --disable-install-capi \
    --with-static-linked-ext \
    --with-out-ext=openssl,fiddle,pty,syslog,win32ole,dbm,gdbm,-test- \
    --without-gmp && \
    make -j$(nproc) ruby && \
    strip ruby && \
    cp ruby /out-ruby && \
    file /out-ruby && \
    ls -lh /out-ruby && \
    ./ruby --version

CMD ["cat", "/out-ruby"]
