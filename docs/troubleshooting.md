# Troubleshooting

**A skill doesn't show up.** Check that the symlink exists and points into this repo:

```bash
ls -la ~/.claude/skills
```

Claude Code notices changes in `~/.claude/skills` while a session is running. If the folder didn't exist when the session started, restart Claude Code.

**Validation fails.** Run the validator on one skill to see the reason:

```bash
scripts/validate.sh my-skill
```

Common causes:

- `name` doesn't match the folder name.
- `description` is missing.
- `plugin.json` is out of sync: run `scripts/sync-plugin.sh`.
- The file doesn't start with a `---` line.

**The installer warns about a conflict.** Another skill with the same name already exists in `~/.claude/skills`. Either rename your skill, or move the other one out of the way and rerun `./install.sh <name>`.

**Validation says a name is duplicated.** Skill and agent names must be unique across domains. Rename one of them.

**A skill shows up twice.** A skill of the same name also comes from somewhere else, such as a plugin (`/dotskills:<name>` or another plugin's namespace) or a synced skill. Don't install this repo both ways on one machine.

**A plugin update didn't take effect.** A new skill is missing or the old behaviour stays after `marketplace update`. That command only refreshes the catalog. Update the plugin itself and restart Claude Code:

```bash
claude plugin update dotskills@dotskills
```

## Behind a TLS-inspecting proxy

Some corporate networks decrypt and re-sign HTTPS traffic with their own root CA (Zscaler is one example). Tools that don't trust that CA fail.

**Symptom.** The installer fails with:

```
curl: (60) SSL certificate problem: self-signed certificate in certificate chain
```

`apt` over plain HTTP can still work, so the network looks fine. It isn't.

**Check who issued the certificate:**

```bash
echo | openssl s_client -connect claude.ai:443 2>/dev/null | grep -E '^(subject|issuer)'
```

If the issuer is your company's proxy and not a public CA, you need the company root CA.

**Get the CA.** Ask IT for the root CA as a PEM file, or export it from your browser's certificate viewer. Where it usually lives on a machine that already works:

- Linux and WSL: `/usr/local/share/ca-certificates/`.
- macOS: Keychain Access. Export it as `.pem`.
- Windows: the certificate store (`certmgr.msc`). Export it as Base-64 `.cer`.

**Trust it system-wide (Debian/Ubuntu):**

```bash
sudo cp company-root-ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates
```

The file must be PEM and end in `.crt`. Rerun the installer after this. `git` uses the system store too.

**Claude Code.** The native install trusts the OS store by default. If you still get certificate errors (for example an npm install on Node older than 22.15), point it at the CA:

```bash
export NODE_EXTRA_CA_CERTS=/etc/ssl/certs/ca-certificates.crt   # or the CA file itself
```

Put it in your shell profile, or in the `env` block of `~/.claude/settings.json` so background agents get it too. If the network also needs an explicit proxy, set `HTTPS_PROXY`. Check what loaded with `/status`. See the official [network configuration](https://code.claude.com/docs/en/network-config) page.

**npm (OpenSpec).** npm keeps its own CA setting:

```bash
npm config set cafile /etc/ssl/certs/ca-certificates.crt
```

**Docker.** Containers don't inherit the host's trusted CAs. Add the CA before installing anything: `docker cp company-root-ca.crt <container>:/usr/local/share/ca-certificates/` and run `update-ca-certificates` inside, or do the same with `COPY` and `RUN` in a Dockerfile.

**Never disable verification** as a fix: no `curl -k`, no `NODE_TLS_REJECT_UNAUTHORIZED=0`, no `npm config set strict-ssl false`.
