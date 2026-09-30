# MCVS General Action

[![GitHub release](https://img.shields.io/github/v/release/schubergphilis/mcvs-general-action)](https://github.com/schubergphilis/mcvs-general-action/releases)
[![License](https://img.shields.io/github/license/schubergphilis/mcvs-general-action)](LICENSE)

<img src="./assets/logos/mcvs-general-action.png" alt="MCVS General Action logo" width="250">

## Overview

The Mission Critical Vulnerability Scanner (MCVS) General Action provides automated security and quality checks for your GitHub repository. This composite action runs multiple validation tests to ensure code quality, security standards, and proper Git workflow practices.

## Features

### Available Testing Types

- **`lint-action`**: Validates GitHub Actions workflow files for security issues
  - Uses [zizmor](https://github.com/zizmorcore/zizmor) to detect security vulnerabilities
  - Checks at minimum `low` severity level

- **`lint-commit`**: Validates commit messages follow [Conventional Commits](https://www.conventionalcommits.org/) format
  - Checks all commits in pull request range
  - Enforces conventional commit standards (feat, fix, docs, etc.)
  - Configuration: `configs/commitlint.config.mjs`

- **`lint-git`**: Enforces Git workflow best practices
  - Ensures the feature branch is up-to-date with the pull request base
    branch (no commits behind)
  - Detects and blocks unwanted merges of the base branch into feature
    branches
  - Compares against the base branch as fetched from the base repository, so
    the checks cannot be bypassed from a fork
  - Identifies fixup/squash commits that should be squashed before merge

- **`lint-links`**: Checks that links in Markdown, HTML and reStructuredText
  files resolve
  - Uses [lychee](https://github.com/lycheeverse/lychee)
  - Also validates `#anchor` fragments in link targets, so a link left behind
    by a renamed heading is caught
  - Fails the job on a broken link and writes a summary to the job page

- **`markdownlint`**: Validates Markdown formatting
  - Uses [markdownlint](https://github.com/DavidAnson/markdownlint)
  - Configuration: `configs/mcvs.markdownlint.yaml`

- **`yamllint`**: Validates YAML file formatting
  - Checks all YAML files against formatting standards
  - Uses hash-pinned dependencies for security
  - Configuration: `configs/yamllint.yaml`

## Usage

### Basic Setup

Create a `.github/workflows/general.yml` file with the following content:

```yml
---
name: general
"on": pull_request
permissions:
  contents: read
  packages: read
jobs:
  mcvs-general-action:
    strategy:
      matrix:
        args:
          - testing-type: lint-action
          - testing-type: lint-commit
          - testing-type: lint-git
          - testing-type: lint-links
          - testing-type: markdownlint
          - testing-type: yamllint
    runs-on: ubuntu-24.04
    steps:
      - uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2
        with:
          persist-credentials: false
      - uses: schubergphilis/mcvs-general-action@v0.5.1
        with:
          testing-type: ${{ matrix.args.testing-type }}
```

### Running Individual Tests

You can run a single test type instead of using a matrix:

```yml
jobs:
  commit-lint:
    runs-on: ubuntu-slim
    steps:
      - uses: actions/checkout@v6
      - uses: schubergphilis/mcvs-general-action@v0.5.1
        with:
          testing-type: lint-commit
```

## Inputs

The `testing-type` values are listed under
[Available Testing Types](#available-testing-types).

| Input                           | Description                                            | Required | Default |
| :------------------------------ | :----------------------------------------------------- | :------- | :------ |
| testing-type                    | Type of test to run                                    | Yes      | N/A     |
| zizmor-action-advanced-security | Upload to Advanced Security instead of failing the job | No       | false   |

## Security Considerations

- All GitHub Actions are pinned to commit SHAs for security
- `lint-action` blocks by default. `zizmor` is run in its annotating
  mode, which exits non-zero when a finding is present. Setting
  `zizmor-action-advanced-security: true` switches it to SARIF upload,
  which **exits zero even when findings exist** and therefore makes
  `lint-action` non-blocking — the findings are filed as code scanning
  alerts rather than gating the pull request
- Python dependencies (yamllint) are installed with `--require-hashes` from
  [`configs/requirements.txt`](configs/requirements.txt)
- NPM packages (commitlint) are installed via `npm ci` with package-lock.json for integrity verification
- The internal checkout used by `lint-commit` and `lint-git` runs with
  `persist-credentials: false`, so the workflow token is never written to
  `.git/config` in the workspace

## License

See [LICENSE](LICENSE) file for details.
