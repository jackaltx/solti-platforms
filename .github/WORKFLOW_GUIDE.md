# GitHub Workflow Guide - solti-platforms

## Branch Strategy

This collection uses a two-branch workflow:

- **test**: Development/integration branch (renamed from dev)
- **main**: Production-ready branch

## Development Workflow

```
feature branch → test → main (via PR)
```

### Working on Features

1. **Create feature branch from test**:
   ```bash
   git checkout test
   git pull
   git checkout -b feature/my-feature
   ```

2. **Develop with checkpoint commits**:
   ```bash
   git add -A
   git commit -m "checkpoint: description"
   # Test locally on Proxmox
   ```

3. **Push to test branch**:
   ```bash
   git checkout test
   git merge feature/my-feature
   git push origin test
   ```

4. **Monitor test branch workflows**:
   - lint.yml: Fast feedback (~5 min)
   - superlinter.yml: Comprehensive validation (~10 min)

5. **When ready, create PR test → main**:
   - GitHub UI: Create Pull Request
   - Triggers ci.yml: Validation (~10 min)
   - Review artifacts before merging

## Workflow Triggers

| Workflow | test branch | main branch | What it does |
|----------|-------------|-------------|--------------|
| **lint.yml** | ✅ push/PR | ✅ push/PR | YAML, Markdown, Ansible lint + syntax |
| **superlinter.yml** | ✅ push/PR | ❌ | Comprehensive validation (Super-Linter) |
| **ci.yml** | ❌ | ✅ push/PR | Role validation + collection build |

## Testing Locally Before Push

### Lint checks
```bash
# YAML
yamllint .

# Markdown
markdownlint "**/*.md" --ignore node_modules

# Ansible
ansible-lint

# Syntax check
ansible-playbook --syntax-check playbooks/*.yml
```

### Integration tests (Proxmox required)
```bash
# Build Proxmox template
./manage-platform.sh proxmox_template build -e template_distribution=rocky9

# Verify template
./platform-exec.sh proxmox_template verify -e template_distribution=rocky9

# Destroy template
./manage-platform.sh proxmox_template destroy -e template_distribution=rocky9
```

### Collection build test
```bash
# Build collection locally
ansible-galaxy collection build

# Should create: jackaltx-solti_platforms-1.0.0.tar.gz
```

## CI Configuration

### No VM Testing in CI

**Important**: This collection manages infrastructure (Proxmox VMs).
GitHub Actions cannot test actual VM creation.

**CI validates**:
- ✅ Syntax and linting
- ✅ Role structure
- ✅ Collection builds successfully
- ❌ Cannot create actual VMs

**Integration testing**:
- Use `manage-platform.sh` locally on Proxmox
- Test on your Proxmox infrastructure before merging to main

### Artifacts

**Collection Build (ci.yml)**:
- **Name**: collection-build
- **Path**: jackaltx-solti_platforms-*.tar.gz
- **Retention**: 5 days
- **Use**: Verify collection packaging works

## Roles

### proxmox_template
**Status**: ✅ Ready
**Purpose**: Build Proxmox VM templates from cloud images
**Distributions**: Rocky 9, Rocky 10, Debian 12

### platform_base
**Status**: 🚧 Planned
**Purpose**: Base platform provisioning (users, SSH, packages)

## Special Considerations

### Proxmox Dependency

This collection requires Proxmox infrastructure:
- Templates are built **ON** the Proxmox host, not localhost
- Must configure inventory with Proxmox hosts
- CI validates code, but cannot test functionality

### Cloud Image Downloads

The proxmox_template role downloads cloud images:
- Rocky: https://dl.rockylinux.org/
- Debian: https://cloud.debian.org/

**Caching**: Downloaded images are cached on Proxmox host

### VMID Assignments

Standard VMIDs used:
- Rocky 9: 7000
- Rocky 10: 7001
- Debian 12: 9001

## Troubleshooting

### Lint failures
Check the failing job in GitHub Actions, fix locally, push again.

### Collection build fails
```bash
# Test locally
ansible-galaxy collection build

# Check for:
# - Missing files referenced in galaxy.yml
# - Invalid YAML syntax
# - Incorrect directory structure
```

### Role validation fails
Ensure each role has:
- `tasks/` directory with `main.yml`
- `defaults/` directory (can be empty)
- `vars/` directory (can be empty)

### Proxmox template build fails
```bash
# Check image download
./platform-exec.sh proxmox_template check_for_update -e template_distribution=rocky9

# Verify Proxmox connectivity
ansible -i inventory.yml platforms -m ping

# Check Proxmox storage
pvesm status
```

## Branch Protection (Recommended)

Configure on GitHub:
- **test branch**: No restrictions (direct push allowed)
- **main branch**:
  - Require pull request reviews
  - Require status checks: lint.yml jobs, ci.yml
  - Do not allow force push
  - Do not allow deletions

## Migration Notes

### dev → test Branch Rename

The development branch was renamed from `dev` to `test` for consistency across Solti collections.

**If you have local dev branch**:
```bash
git branch -m dev test
git fetch origin
git branch -u origin/test test
```

**If you have dev checked out remotely**:
```bash
git fetch origin
git checkout -b test origin/test
git branch -D dev  # Delete local dev
```

## Next Steps

1. **Push renamed test branch**:
   ```bash
   git push -u origin test
   git push origin --delete dev  # Delete remote dev
   ```

2. **Update GitHub default branch** (if needed):
   - Settings → Branches → Default branch → main

3. **Test lint.yml** on test branch:
   - Push a change and verify all 4 jobs pass

4. **Test collection build**:
   - Trigger ci.yml workflow manually
   - Download collection artifact and verify

5. **Test on Proxmox**:
   - Build templates using manage-platform.sh
   - Verify templates work correctly
   - Then create PR test → main

## Known Limitations

### CI Cannot Test VM Creation

**Why**: GitHub Actions runners cannot access Proxmox infrastructure

**Impact**: CI validates code quality, not functionality

**Solution**: Always test locally before PR:
1. Build template on Proxmox
2. Verify template works
3. Destroy template (cleanup)
4. Then push to test → main

### Self-Hosted Runner Option

If you want full integration testing in CI:
1. Set up GitHub Actions runner on Proxmox host or nearby
2. Modify ci.yml to use `runs-on: self-hosted`
3. Add actual VM creation tests

This is **optional** and not included in the standard workflow.
