# GitHub Security Setup Guide

This guide helps you configure GitHub's advanced security features for the EchoWright repository.

## 🔒 Required Security Settings

### 1. Enable Code Scanning

**Why**: GitHub Code Scanning analyzes your code for security vulnerabilities and quality issues.

**Steps**:
1. Go to your repository on GitHub
2. Click **Settings** tab
3. Click **Security** in the left sidebar  
4. Click **Code scanning and analysis**
5. Click **Set up** next to "Code scanning"
6. Choose **GitHub Actions** 
7. Select **Advanced** setup
8. GitHub will create a default workflow file

**Alternative CLI Method**:
```bash
# Using GitHub CLI
gh api repos/:owner/:repo/code-scanning/default-setup \
  --method PATCH \
  --field state=configured
```

### 2. Enable Dependabot Alerts

**Steps**:
1. In **Settings** → **Security**
2. Enable **Dependabot alerts**
3. Enable **Dependabot security updates** 
4. Enable **Dependabot version updates**

### 3. Enable Secret Scanning

**Steps**:
1. In **Settings** → **Security** 
2. Enable **Secret scanning**
3. Enable **Push protection** (recommended)

### 4. Configure Security Policy

**Steps**:
1. In repository root, create `.github/SECURITY.md`
2. Add vulnerability reporting instructions
3. Define security contact information

## 🛡️ Workflow Permissions

Ensure your repository has proper permissions for security workflows:

### Repository Settings
1. Go to **Settings** → **Actions** → **General**
2. Under **Workflow permissions**, select:
   - **Read and write permissions** 
   - Check **Allow GitHub Actions to create and approve pull requests**

### Branch Protection
1. Go to **Settings** → **Branches**
2. Add branch protection rule for `main`:
   - Require status checks to pass
   - Require branches to be up to date
   - Include administrators

## 📋 Security Workflow Status

After enabling these features, your security workflows will provide:

### ✅ Working Features
- **Dependency Scanning**: Checks for vulnerable dependencies
- **Static Analysis**: Code quality and security analysis  
- **Container Scanning**: Docker image vulnerability scanning
- **Infrastructure Scanning**: Terraform/Kubernetes security
- **Secrets Scanning**: Prevents credential leaks

### 🔧 Troubleshooting

**Issue**: "Code scanning is not enabled"
- **Solution**: Follow Step 1 above to enable code scanning

**Issue**: "Resource not accessible by integration"  
- **Solution**: Check workflow permissions in Step 4 above

**Issue**: "Path does not exist: *.sarif"
- **Solution**: Security scan failed to generate results (check scan logs)

**Issue**: "TruffleHog BASE and HEAD commits are the same"
- **Solution**: Fixed in workflow - now handles push vs PR events differently

## 🔗 Related Documentation

- [GitHub Code Scanning Docs](https://docs.github.com/en/code-security/code-scanning)
- [Dependabot Documentation](https://docs.github.com/en/code-security/dependabot) 
- [Secret Scanning Guide](https://docs.github.com/en/code-security/secret-scanning)
- [Security Advisories](https://docs.github.com/en/code-security/security-advisories)

## 📞 Support

If you encounter issues with security setup:

1. Check the [GitHub Status Page](https://githubstatus.com)
2. Review workflow logs in **Actions** tab
3. Consult [GitHub Community](https://github.community) for help
4. Contact repository maintainers for EchoWright-specific issues

---

**Note**: Some security features require GitHub Pro, GitHub Team, or GitHub Enterprise. Check your repository's plan for feature availability.