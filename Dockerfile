# web-admin builder
# -----------------
FROM --platform=$BUILDPLATFORM node:16 as build-web-admin

# Change to build dir
WORKDIR /build

# Build and cache deps first
COPY ./web-admin/package.json /build/web-admin/package.json
COPY ./web-admin/package-lock.json /build/web-admin/package-lock.json
WORKDIR /build/web-admin
RUN npm install

# Copy in source
COPY ./web-admin /build/web-admin

# Build web-admin
RUN npm run build


# sensei builder
# --------------
FROM --platform=$BUILDPLATFORM rust:1.56 as build-sensei

# Change to build dir
WORKDIR /build

# Add rustfmt
RUN rustup component add rustfmt

# Figure out which target to cross compile for
ARG TARGETARCH
RUN [ "$TARGETARCH" = "arm64" ] && echo "aarch64-unknown-linux-musl" > /target || true
RUN [ "$TARGETARCH" = "amd64" ] && echo "x86_64-unknown-linux-musl" > /target || true

# Add the target
RUN rustup target add $(cat /target)

# Install cross platform gcc toolchains
RUN apt-get update
RUN apt-get install -y gcc-x86-64-linux-gnu gcc-aarch64-linux-gnu

# Cache deps first
COPY Cargo.toml .
COPY Cargo.lock .
RUN mkdir "src"
RUN echo "fn main() {}" > "src/main.rs"
RUN echo "fn main() {}" > "src/cli.rs"

# Cross compile deps
RUN cargo build --target=$(cat /target) --verbose --release

# Clean up dummy files
RUN rm "src/main.rs"
RUN rm "src/cli.rs"

# Copy in source
COPY . .

# Copy in built web admin
COPY --from=build-web-admin /build/web-admin/build/ /build/web-admin/build/

# Cross compile sensei
RUN cargo build --target=$(cat /target) --verbose --release

# Move to a canonical location so we can copy it in the next build stage
RUN cp /build/target/$(cat /target)/release/senseid /build/target/release/senseid


# Final image
# -----------
FROM --platform=$TARGETPLATFORM rust:1.56

# copy the build artifact from the build stage
COPY --from=build-sensei /build/target/release/senseid .

# set the startup command to run your binary
CMD ["./senseid"]