# musl静的リンク bash 5.2 ビルド (Cosmo Linux用)
#
# ビルド:
#   docker build -f Dockerfile.bash -t cosmo-bash .
# 取得:
#   docker run --rm cosmo-bash > rootfs/packages/bash
#   chmod +x rootfs/packages/bash
FROM alpine:3.20

# ビルドツール
RUN apk add --no-cache \
    build-base file wget \
    ncurses-dev ncurses-static \
    readline-dev readline-static

# bash 5.2.37 ソースからビルド (完全静的リンク)
RUN wget https://ftp.gnu.org/gnu/bash/bash-5.2.37.tar.gz && \
    tar xzf bash-5.2.37.tar.gz && \
    cd bash-5.2.37 && \
    LDFLAGS="-static" CFLAGS="-Os -DHAVE_DLOPEN=0" \
    ./configure \
    --without-bash-malloc \
    --enable-static-link \
    --disable-nls \
    --prefix=/usr && \
    make -j$(nproc) && \
    strip bash && \
    cp bash /out-bash && \
    file /out-bash && \
    ls -lh /out-bash

CMD ["cat", "/out-bash"]
