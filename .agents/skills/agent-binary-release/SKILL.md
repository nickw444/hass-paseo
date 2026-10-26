---
name: agent-binary-release
description: Bump the Paseo runtime and bundled coding agent CLIs in the Paseo Home Assistant add-on to current stable releases, then publish the next patch release. Use for the scheduled Paseo and agent update and release workflow in this repository.
---

# Paseo runtime and agent binary release

Update the Paseo runtime, its matching web UI source, and the bundled coding agent CLIs in this repository and publish a new add-on patch release. A scheduled invocation of this skill is authorization to publish the update without asking again.

## Release procedure

1. **Confirm the checkout is safe to release.** Require a clean worktree on `master`, including the Paseo submodule. Fetch `origin` and require local `master` to match `origin/master`. Initialize `paseo/vendor/paseo` if needed. Never overwrite a user's changes or force-push.

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

   For Paseo, resolve the latest published stable release from `getpaseo/paseo` on GitHub, excluding drafts and prereleases. Fetch its release tag into `paseo/vendor/paseo` and resolve the tag to its full commit SHA (peel annotated tags). Confirm that the source root `package.json` version matches the release version and that `ghcr.io/getpaseo/paseo:<version>` is published for both `linux/amd64` and `linux/arm64`, for example with `docker buildx imagetools inspect`. Keep the runtime image and web UI source on the same release; do not substitute the default branch or `latest` image tag. If a newer stable release is missing its image or has incompatible source, report the blocker rather than silently skipping the Paseo update.

3. **No-op if all runtime and agent pins match.** Compare the resolved Paseo version and commit, agent versions, and Cursor build ID with the current pins. If none have advanced, make no commit or release and report that the scheduled run found no updates. Do not bump the add-on version just because the schedule ran. Do not downgrade a pin when upstream reports an older version; report the discrepancy.

4. **Choose the next add-on patch version.** Increment the patch component of `paseo/config.yaml` by one, preserving the major and minor components. Confirm that the new `v<version>` tag does not already exist locally or on `origin`.

5. **Update every copy of each changed pin.** Keep these locations synchronized:

   - `paseo/Dockerfile`: all `PASEO_VERSION` defaults, `PASEO_COMMIT`, the `FROM ghcr.io/getpaseo/paseo:<version>` runtime image, provider `ARG` defaults, Cursor build ID, and both Cursor SHA-256 values.
   - `paseo/vendor/paseo`: check out the resolved Paseo release commit with detached HEAD and stage the submodule pointer in the parent repository. Keep the submodule source clean; maintain add-on patches in `paseo/patches/`.
   - `.github/workflows/build.yaml`: matching Paseo and provider build arguments and the workflow-dispatch version default.
   - `paseo/build.yaml`: Paseo version/commit, Codex version/release tag, Claude Code, OpenCode, and Pi versions.
   - `paseo/config.yaml`: new add-on version.
   - `paseo/tests/test_static.sh`: expected add-on version, Paseo version/commit expectations (including submodule HEAD), Copilot version, Cursor build ID, and Cursor hashes.
   - `paseo/CHANGELOG.md`: add a top entry listing the changed Paseo and agent versions.

   Leave Pi MCP Adapter, the Home Assistant CLI, and base images other than the Paseo runtime image unchanged. Preserve existing pins when their stable upstream versions have not changed.

   When Paseo changes, review the upstream release notes and source diff for compatibility with the add-on startup, provider configuration, and ingress behavior. Check both source patches (`0001` and `0002`) against the new checkout. Check the Expo Router dependency and `0003` dependency patch against the installed dependency used by the web builder; its current version assertion may need updating. Adapt patches and Docker build inputs only as needed for the new release, retaining ingress behavior and keeping matching checks current. If a patch is already implemented upstream, verify that behavior before removing the patch and its build/test references. Do not drop a failing patch or bypass a build assertion just to pass checks. Stop before publishing if compatibility cannot be established.

6. **Review and check the release candidate.** Ensure the diff only contains the pin updates, Paseo submodule pointer, version, changelog, corresponding static expectations, and any necessary Paseo compatibility changes described above. Run:

   ```bash
   git diff --check
   bash paseo/tests/test_static.sh
   bash paseo/tests/test_provider_mcp_config.sh
   bash paseo/tests/test_ingress_rewrite.sh
   ```

   Ensure every duplicated version/build/hash is identical across its locations. Do not proceed if any check fails.

7. **Commit and push the branch and tag.** Use a message such as `chore: update Paseo and bundled coding agents for v<version>`, reflecting what changed. Create an annotated `v<version>` tag on that commit, push `master`, then push the tag. Do not force-push or move an existing tag.

8. **Wait for the tag workflows before publishing the GitHub release.** Find the workflows triggered by `v<version>` and wait for both lint and the amd64 and aarch64 image publishing jobs to finish successfully. The image workflow is the evidence that the Paseo runtime version check, patched web UI, provider packages, architecture-specific archives, checksums, and container images all build. If a workflow fails, do not create the GitHub release or delete/move the tag. Report the failed job and stop so the cause can be fixed in a new patch release. A transient workflow failure may be rerun once if its logs show no source change is needed.

9. **Create the GitHub release after the workflows pass.** Use the changelog entry as the release notes and the existing pushed `v<version>` tag as the release target. Confirm the release is published, the workflows passed, and the worktree is clean before reporting completion.

## Report

For a release, report the new add-on version, commit, changed Paseo version/source commit and agent versions, GitHub release URL, and links to the successful lint and image workflows. For a no-op or blocked release, state that clearly and identify the reason.
