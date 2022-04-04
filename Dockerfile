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

COPY --from=build-web-admin /build/web-admin/build/ /build/web-admin/build/

RUN rustup component add rustfmt

# Figure out which target to cross compile for
ARG TARGETPLATFORM
RUN [["$TARGETPLATFORM" == "linux/arm64" ]] && echo "aarch64-unknown-linux-gnu" > /target || true
RUN [["$TARGETPLATFORM" == "linux/amd64" ]] && echo "x86_64-unknown-linux-gnu" > /target || true

RUN rustup target add $(cat /target)

RUN cargo build --target=$(cat /target) --verbose --release


# Final image
FROM --platform=$TARGETPLATFORM rust:1.56

# copy the build artifact from the build stage
COPY --from=build-sensei /build/target/release/senseid .

# set the startup command to run your binary
CMD ["./senseid"]