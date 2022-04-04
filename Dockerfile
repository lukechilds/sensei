# web-admin builder
FROM --platform=$BUILDPLATFORM node:16 as build-web-admin

WORKDIR /build

COPY . .

WORKDIR /build/web-admin
RUN npm install
RUN npm run build


# sensei builder
FROM --platform=$BUILDPLATFORM rust:1.56 as build-sensei

WORKDIR /build

COPY . .

RUN rustup component add rustfmt

# Figure out which target to cross compile for
ARG BUILDARCH
RUN [ "$BUILDARCH" = "arm64" ] && echo "aarch64-unknown-linux-gnu" > /target || true
RUN [ "$BUILDARCH" = "amd64" ] && echo "x86_64-unknown-linux-gnu" > /target || true

# Add the target
RUN rustup target add $(cat /target)

# Copy in the source
# (We do this just in time so the above commands can run async while web-admin is building)
COPY --from=build-web-admin /build/web-admin/build/ /build/web-admin/build/

# Cross compile to the target
RUN cargo build --target=$(cat /target) --verbose --release

# Move to a canonical location so we can copy it in the next build stage
RUN cp /build/target/$(cat /target)/release/senseid /build/target/release/senseid


# Final image
FROM --platform=$TARGETPLATFORM rust:1.56

# copy the build artifact from the build stage
COPY --from=build-sensei /build/target/release/senseid .

# set the startup command to run your binary
CMD ["./senseid"]