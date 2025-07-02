# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

## Reporting a Vulnerability

We take the security of the FIAP-X Notification Service seriously. If you believe you have found a security vulnerability, please report it to us as described below.

### How to Report a Security Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via email to: **security@fiapx.wecando.click**

You should receive a response within 48 hours. If for some reason you do not, please follow up via email to ensure we received your original message.

Please include the following information in your report:

- Type of issue (buffer overflow, SQL injection, cross-site scripting, etc.)
- Full paths of source file(s) related to the manifestation of the issue
- The location of the affected source code (tag/branch/commit or direct URL)
- Any special configuration required to reproduce the issue
- Step-by-step instructions to reproduce the issue
- Proof-of-concept or exploit code (if possible)
- Impact of the issue, including how an attacker might exploit the issue

This information will help us triage your report more quickly.

## Security Measures

### Current Security Implementations

- **🔒 Container Security**: Distroless images, non-root user, read-only filesystem
- **🔐 Secrets Management**: Kubernetes secrets, no hardcoded credentials
- **🛡️ Static Analysis**: Gosec security scanning in CI/CD
- **📊 Dependency Scanning**: Automated vulnerability checks
- **🔒 Network Security**: TLS/SSL for SMTP, network policies
- **🚨 Monitoring**: Security event logging and alerting

### Best Practices

1. **Never commit secrets** to the repository
2. **Use environment variables** for configuration
3. **Keep dependencies updated** with security patches
4. **Follow least privilege principle** for IAM roles
5. **Enable audit logging** for all operations
6. **Use strong authentication** for all services

## Security Updates

Security updates will be released as soon as possible after a vulnerability is confirmed. We recommend:

- Monitor this repository for security updates
- Subscribe to GitHub security advisories
- Keep your deployment updated to the latest version
- Review security logs regularly

## Contact

For any security-related questions or concerns, contact:
- Email: security@fiapx.wecando.click
- GitHub: [@hqmoraes](https://github.com/hqmoraes)

---

**Note**: This security policy is part of the FIAP-X project security framework.
