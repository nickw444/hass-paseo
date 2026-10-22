---
name: agent-binary-release
description: Bump the bundled coding agent CLIs in the Paseo Home Assistant add-on to current stable releases, then publish the next patch release. Use for the scheduled agent update and release workflow in this repository.
---

# Paseo agent binary release

Update the bundled coding agent CLIs in this repository and publish a new add-on patch release. A scheduled invocation of this skill is authorization to publish the update without asking again.

## Release procedure

1. **Confirm the checkout is safe to release.** Require a clean worktree on `master`. Fetch `origin` and require local `master` to match `origin/master`. Never overwrite a user's changes or force-push.

2. **Resolve stable upstream versions from authoritative sources.** Use npm's `latest` dist-tag, not prereleases:

   ```bash
   npm view @openai/codex version
   npm view @anthropic-ai/claude-code version
   npm view opencode-ai version
   npm view @mariozechner/pi-coding-agent version
   npm view @github/copilot version
   ```

   Get Cursor Agent's current immutable build ID from Cursor's official installer and derive the Linux archive URL from it:

   ```bash
   curl -fsSL https://cursor.com/install | rg 'DOWNLOAD_URL='
   ```

   The installer URL has the form `https://downloads.cursor.com/lab/<build-id>/linux/x64/agent-cli-package.tar.gz`. Use that same `<build-id>` with both `x64` and `arm64`. Download each archive and calculate its SHA-256 with `sha256sum`; do not reuse an old checksum or infer a new one from the version string.

   For Codex, confirm that `rust-v<version>` exists at `https://github.com/openai/codex/releases` and contains both `codex-package-x86_64-unknown-linux-musl.tar.gz` and `codex-package-aarch64-unknown-linux-musl.tar.gz`, plus `codex-package_SHA256SUMS`. The Docker build verifies the downloaded Codex archive against that manifest.

3. **No-op if all agent pins match.** Compare the resolved versions and Cursor build ID with the current pins. If none have advanced, make no commit or release and report that the scheduled run found no updates. Do not bump the add-on version just because the schedule ran.

4. **Choose the next add-on patch version.** Increment the patch component of `paseo/config.yaml` by one, preserving the major and minor components. Confirm that the new `v<version>` tag does not already exist locally or on `origin`.

5. **Update every copy of each changed pin.** Keep these locations synchronized:

   - `paseo/Dockerfile`: all provider `ARG` defaults, Cursor build ID, and both Cursor SHA-256 values.
   - `.github/workflows/build.yaml`: matching build arguments and the workflow-dispatch version default.
   - `paseo/build.yaml`: Codex version/release tag, Claude Code, OpenCode, and Pi versions.
   - `paseo/config.yaml`: new add-on version.
   - `paseo/tests/test_static.sh`: expected add-on version, Copilot version, Cursor build ID, and Cursor hashes.
   - `paseo/CHANGELOG.md`: add a top entry listing the changed agent versions.

   Pi MCP Adapter, Paseo, the Home Assistant CLI, and base images are not coding agents; leave their pins alone in this workflow. Preserve an agent's existing version when its upstream `latest` value has not changed.

6. **Review and check the release candidate.** Ensure the diff only contains the pin updates, version, changelog, and corresponding static expectations. Run:

   ```bash
   git diff --check
   bash paseo/tests/test_static.sh
   bash paseo/tests/test_provider_mcp_config.sh
   bash paseo/tests/test_ingress_rewrite.sh
   ```

   Ensure every duplicated version/build/hash is identical across its locations. Do not proceed if any check fails.

7. **Commit and push the branch and tag.** Use a message such as `chore: update bundled coding agents for v<version>`. Create an annotated `v<version>` tag on that commit, push `master`, then push the tag. Do not force-push or move an existing tag.

8. **Wait for the tag workflows before publishing the GitHub release.** Find the workflows triggered by `v<version>` and wait for both lint and the amd64 and aarch64 image publishing jobs to finish successfully. The image workflow is the evidence that the provider packages, architecture-specific archives, checksums, and container images all build. If a workflow fails, do not create the GitHub release or delete/move the tag. Report the failed job and stop so the cause can be fixed in a new patch release. A transient workflow failure may be rerun once if its logs show no source change is needed.

9. **Create the GitHub release after the workflows pass.** Use the changelog entry as the release notes and the existing pushed `v<version>` tag as the release target. Confirm the release is published, the workflows passed, and the worktree is clean before reporting completion.

## Report

For a release, report the new version, commit, changed agent versions, GitHub release URL, and links to the successful lint and image workflows. For a no-op or blocked release, state that clearly and identify the reason.
