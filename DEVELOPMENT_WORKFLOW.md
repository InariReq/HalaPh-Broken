# Development Workflow for HalaPH Flutter Project

## Critical Rules Before Making Changes

### 1. ALWAYS Create a Git Branch First
```bash
git checkout -b feature/[feature-name]
```
**Never work directly on main branch** - This allows easy rollback if things go wrong

### 2. Test Before Major Changes
```bash
flutter analyze
flutter test
```
Run analysis before starting any major work
Ensure baseline is working before making changes

### 3. Make Incremental Changes
- Change ONE thing at a time
- Test after each change
- Don't overhaul multiple files simultaneously

## Emergency Procedures

### If Something Breaks:

#### Immediate Rollback:
```bash
git checkout -- lib/screens/route_options_screen.dart
git reset --hard HEAD
```
- Revert individual files first
- Full reset if needed

#### Check Git Status:
```bash
git status
git diff
```
- See exactly what changed
- Identify problematic files

#### Use Git Stash:
```bash
git stash
git stash pop
```
- Save work temporarily
- Restore when ready

## Project-Specific Considerations

### Critical Areas:
- **Route functionality** is sensitive - small syntax errors break compilation
- **Widget hierarchy** matters - Flutter is strict about structure
- **Import dependencies** - removing imports can break references

### Best Practices:
- Never delete entire methods without checking references
- Always fix syntax errors immediately - don't let them accumulate
- Use Flutter Hot Reload to test changes in real-time
- Keep the app running while making changes to catch issues early

## Common Git Commands

### Branch Management:
```bash
# List branches
git branch

# Create new branch
git checkout -b feature/branch-name

# Switch branches
git checkout branch-name

# Merge branch
git checkout main
git merge feature/branch-name

# Delete branch
git branch -d feature/branch-name
```

### Commit Workflow:
```bash
# Stage changes
git add .

# Commit changes
git commit -m "Descriptive commit message"

# Push to remote
git push origin feature/branch-name
```

## Testing Commands

### Analysis:
```bash
flutter analyze
```

### Running Tests:
```bash
flutter test
```

### Running the App:
```bash
flutter run
# For hot reload: Press 'r' in terminal
# For hot restart: Press 'R' in terminal
```

## Key Mistakes to Avoid

1. **Don't try to revert everything at once** - use git to properly rollback changes
2. **Don't work on main branch** - always use feature branches
3. **Don't make multiple simultaneous changes** - work incrementally
4. **Don't ignore syntax errors** - fix them immediately
5. **Don't delete code without checking references** - search for usages first

## Remember
The key to successful development is **version control**. Always use git to track changes and enable easy rollbacks when needed.
