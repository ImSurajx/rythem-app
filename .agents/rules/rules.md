# Step-by-Step Implementation & User Approval Rules

## 1. No Autonomous Full Implementations
- **DO NOT** begin implementing large features, architectural refactors, or entire multi-step stages on your own.
- **DO NOT** make assumptions or execute multiple major stages in a single pass without user alignment.

## 2. Granular Task Decomposition
- Always deconstruct complex tasks or features into **small, discrete, and reviewable steps**.
- Clearly state what the current single step is before writing code or running modifying commands.

## 3. Mandatory Checkpoints & User Permission
- Implement **only one step at a time**.
- When that single step is completed and verified:
  1. Show what was accomplished in that specific step.
  2. Stop execution immediately.
  3. **Ask the user for explicit permission** before advancing to the next step.
- Proceed to the next step **ONLY** after receiving the user's explicit approval.

## 4. Git Commit Standards
- Whenever committing code, always use the `-s` sign-off flag: `git commit -s`.
- Keep commit messages concise, descriptive, and formatted per conventional standards.

## 5. Release & Changelog Standards
- Whenever creating a release, publishing tags, or setting up GitHub Actions release workflows:
  - **Always include a detailed Changelog** documenting features, architectural decisions, and fixes.
  - Maintain and update [CHANGELOG.md](file:///Users/itsurajx/Developer/rythem-app/CHANGELOG.md) in the repository with clear version sections.
