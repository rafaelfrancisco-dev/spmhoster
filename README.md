# SPM Hoster

SPM Hoster is a lightweight Swift Vapor application designed to host and serve Swift Package Manager (SPM) artifacts. It allows you to upload `.zip` files containing your binary frameworks and automatically generates the necessary `Package.swift` manifest for integration.

## Features

- **Artifact Hosting**: Upload and serve binary artifacts (zipped XCFrameworks).
- **Automatic Manifest Generation**: Returns a valid `Package.swift` manifest upon upload, ready for use in your projects.
- **Configurable Storage**: Choose where artifacts are stored on the server.
- **Size Limits**: Enforce maximum artifact folder sizes with automatic cleanup of old artifacts.
- **Collision Handling**: Automatically renames files to prevent overwriting existing artifacts.

## Getting Started

### Prerequisites

- Swift 5.9 or later
- macOS or Linux

### Building

To build the project in release mode:

```bash
swift build -c release
```

### Running

To start the server:

```bash
swift run spmhoster
```

By default, the server will bind to `127.0.0.1:8080` (or `::1:8080`).

## Configuration

The application supports several command-line arguments to configure its behavior:

| Argument | Shorthand | Description | Default |
| :--- | :--- | :--- | :--- |
| `--hostname` | `-H` | Set the hostname the server will run on. | `127.0.0.1` |
| `--port` | `-p` | Set the port the server will run on. | `8080` |
| `--bind` | `-b` | Bind to the given address (hostname:port). | |
| `--artifacts-path` | | Custom absolute path for the artifacts folder. | `./artifacts/` |
| `--max-artifacts-size` | | Maximum size of the artifacts folder (e.g., `500MB`, `1GB`). Oldest files are deleted if limit is exceeded. | Unlimited |

### Examples

Run on a specific port:

```bash
swift run spmhoster --port 8081
```

Run with a custom artifacts path and size limit:

```bash
swift run spmhoster --artifacts-path /var/www/artifacts --max-artifacts-size 2GB
```

## API Usage

### Upload Artifact

Upload a `.zip` file containing your binary framework.

**Endpoint:** `POST /upload`
**Body:** Raw binary data
**Headers:**

- `X-Filename`: The name of the file (must end in `.zip`).

**Example (cURL):**

```bash
curl -X POST http://localhost:8080/upload \
  -H "X-Filename: MyFramework.zip" \
  --data-binary @MyFramework.zip
```

**Response:**
A complete `Package.swift` manifest string that you can use to distribute your binary target.

### Download Artifact

Download a stored artifact.

**Endpoint:** `GET /artifacts/:filename`

**Example:**
`http://localhost:8080/artifacts/MyFramework.zip`

### Certificates

Since the server uses a self-signed certificate by default, you may need to trust it manually.

**Download Certificate:**

```bash
curl -o cert.pem http://localhost:8080/cert
```

**Trust Certificate (macOS):**

```bash
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain cert.pem
```
