---
name: mm-dev-docs
description: "Claude-solo command skill"
---

# mm-dev-docs

Claude-solo command skill

## Instructions
# /dev-docs Command

Creates comprehensive strategic plan with three essential documentation files for feature development.

## Usage
```
/dev-docs [feature-name]
```

## What it does

This command automatically generates three critical documentation files that serve as the foundation for feature development:

### 1. Plan Document ([feature]-plan.md)
- Executive summary
- Implementation phases with timelines
- Technical approach and architecture decisions
- Risk assessment and mitigation strategies
- Success metrics and KPIs
- Detailed task breakdown

### 2. Context Document ([feature]-context.md)
- Critical file paths and their purposes
- Architectural decisions and rationale
- Dependencies (internal and external)
- Integration points
- Related documentation links
- Historical decisions and trade-offs

### 3. Tasks Document ([feature]-tasks.md)
- Checkbox-formatted task list
- Tasks organized by implementation phase
- Progress tracking markers
- Dependencies between tasks
- Estimated time for each task
- Acceptance criteria

## Process Flow

1. **Analysis**: Examine the feature request and existing codebase
2. **Planning**: Create structured implementation approach
3. **Documentation**: Generate the three documentation files
4. **Review**: Present plan for approval
5. **Tracking**: Use tasks.md for progress monitoring

## Example Output Structure

```
feature-auth/
├── feature-auth-plan.md      # Strategic plan
├── feature-auth-context.md    # Technical context
└── feature-auth-tasks.md      # Task checklist
```

## Integration Points

- Works with `/dev-docs-update` to refresh documentation
- Tracked by file-edit-tracker hook
- Tasks can be imported into project management tools
- Context used by Claude for maintaining consistency

## Best Practices

1. **Run before implementation**: Always create docs before coding
2. **Keep updated**: Use `/dev-docs-update` as implementation evolves
3. **Review thoroughly**: Plans should be reviewed before proceeding
4. **Track progress**: Check off tasks in tasks.md as completed
5. **Reference context**: Keep context.md open for quick reference

## Sample Invocation

```typescript
// When starting a new authentication feature
/dev-docs jwt-authentication

// Output:
// ✅ Created: jwt-authentication-plan.md
// ✅ Created: jwt-authentication-context.md
// ✅ Created: jwt-authentication-tasks.md
//
// Plan Summary:
// - 3 phases identified
// - 24 tasks created
// - Estimated timeline: 5 days
// - 2 high-priority risks identified
//
// Ready for review and implementation.
```

## Advanced Options

```
/dev-docs [feature-name] --options

Options:
  --template [type]     Use specific template (api|ui|service|full-stack)
  --priority [level]    Set priority level (low|medium|high|critical)
  --team [size]        Adjust for team size (solo|small|large)
  --timeline [days]     Set target timeline
  --include-tests      Add comprehensive test planning
  --include-migration  Add data migration planning
```

## Templates

### API Template
- Endpoint definitions
- Request/response schemas
- Authentication requirements
- Rate limiting considerations
- API documentation

### UI Template
- Component hierarchy
- State management approach
- Design system integration
- Accessibility requirements
- Performance targets

### Service Template
- Service boundaries
- Inter-service communication
- Data consistency approach
- Failure handling
- Monitoring strategy

## Automation

Can be triggered automatically when:
- Creating new feature branch
- Opening PR with 'feature' label
- Running `npm run plan [feature]`

## Tips

1. Be specific with feature names for better documentation
2. Review generated plans before starting implementation
3. Update tasks.md regularly to track progress
4. Use context.md for onboarding new team members
5. Archive completed documentation for future reference
