# Lambda CLI

A CLI tool for managing Lambda Cloud resources.

## Features

- Create, connect, set up, and delete Lambda Cloud instances
- SSH key management
- Automatic completion for bash, fish, and zsh

## Version Management

This package uses environment variables for versioning when building with GitHub Actions:
- When tagged (e.g., `v1.0.0`): Version will be "1.0.0"
- Default version: "0.0.0" (used for local development)

## Release Process

To release a new version:

1. Ensure all changes are committed to the main branch
2. Create and push a new tag with the format `vX.Y.Z`:

```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

3. The GitHub Actions workflow will automatically:
   - Create a GitHub release
   - Build the Lambda CLI for multiple platforms
   - Upload the binaries as artifacts

### Local Build

To build the package locally:

```bash
# Set version manually
export LAMBDA_VERSION=1.0.0
nix build .#apps.$(nix eval --impure --expr 'builtins.currentSystem').lambda

# Or just use the default version
nix build .#apps.$(nix eval --impure --expr 'builtins.currentSystem').lambda
```

## Integration with Nix/Darwin System

The Lambda CLI is automatically included in the system when:

1. Using `darwin-rebuild switch` on macOS
2. Using `home-manager switch` on any platform

The version is determined by the `LAMBDA_VERSION` environment variable if set, otherwise it defaults to "0.0.0".