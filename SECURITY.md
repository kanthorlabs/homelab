# Security policy

## Report a vulnerability

Do not open a public issue for a vulnerability.

Report it privately through **Security** > **Report a vulnerability** on the GitHub page of this repository. Include the affected file, the steps to reproduce and the impact.

## Rules for contributions

- Commit no secret, token, key, password, real host name or address.
- Put a value of a single server in `.env`. Add its name with an example value to `.env.example`.
- Bind every service to `127.0.0.1`.
- Pin every GitHub Action to a full commit SHA.
