# Contributing to WA-Forensics

Thank you for your interest in contributing! This is an academic research project developed at Malawi University of Science and Technology. Contributions are welcome from forensic researchers, security professionals, and open-source developers.

## How to Contribute

### 1. Fork and Clone

```bash
# Fork the repo on GitHub, then:
git clone https://github.com/YOUR-USERNAME/wa-forensics.git
cd wa-forensics
git remote add upstream https://github.com/your-org/wa-forensics.git
```

### 2. Create a Branch

Use a descriptive branch name:

```bash
git checkout -b feature/wal-recovery-improvements
git checkout -b fix/crypt15-decryption
git checkout -b docs/add-screenshots
```

### 3. Make Your Changes

- Keep changes focused — one feature or fix per pull request
- Follow the existing Bash code style (2-space indentation, `local` for function variables)
- Add comments for any non-obvious forensic logic
- Test against at least one real or simulated WhatsApp database

### 4. Commit with a Clear Message

```bash
git add .
git commit -m "feat: add crypt15 decryption support in decrypt_helper.py"
git commit -m "fix: handle NULL jid_row_id in group chat sender resolution"
git commit -m "docs: add usage screenshots to docs/screenshots/"
```

### 5. Push and Open a Pull Request

```bash
git push origin feature/your-feature-name
```

Then open a Pull Request on GitHub against the `main` branch. Describe:
- What the change does
- Why it's needed
- How it was tested

## Code Standards

- All database access **must** use `sqlite3 -readonly` — never modify evidence
- New analysis queries must follow the schema-agnostic pattern using `detect_*` functions
- All new actions must call `log_action()` for audit trail compliance
- HTML reports must embed chain-of-custody metadata

## Reporting Issues

Open a GitHub Issue with:
- WhatsApp version and database schema version (run `sqlite3 msgstore.db ".tables"`)
- The exact error message or unexpected behaviour
- Steps to reproduce (using sanitised/synthetic test data — never real evidence)

## ⚠️ Important: No Real Evidence in Issues or PRs

Never upload real WhatsApp databases, key files, or any data containing personal information in issues, pull requests, or comments. Use only synthetic or anonymised test data.
