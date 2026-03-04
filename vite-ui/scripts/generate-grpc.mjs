import { execSync } from "child_process";
import fs from "fs";
import path from "path";

const root = process.cwd();

console.log("🔧 Generating gRPC TypeScript...");

execSync(`
  npx protoc \
    -I=./protobuf \
    --plugin=protoc-gen-ts=./node_modules/.bin/protoc-gen-ts \
    --ts_out=long_type_string:./grpc \
    --grpc-web_out=import_style=typescript,mode=grpcweb:./grpc \
    ./protobuf/rss.proto
  `, { stdio: "inherit" });

const src = path.join(root, "grpc");
const dest = path.join(root, "grpc-generated");

if (!fs.existsSync(dest)) {
    fs.mkdirSync(dest, { recursive: true });
}

for (const file of fs.readdirSync(src)) {
    if (file.endsWith(".ts")) {
        fs.copyFileSync(
            path.join(src, file),
            path.join(dest, file)
        );
    }
}

console.log("✅ gRPC TypeScript (.ts only) generated & synced");