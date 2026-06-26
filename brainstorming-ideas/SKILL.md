---
name: brainstorming-ideas
description: Explores project context, asks clarifying questions, and proposes designs. Use prior to creative work, feature development, or system modifications.
---

# Brainstorming Ideas Into Designs

## When to use this skill
- User asks to brainstorm, plan, or design a new feature
- Before creating features, building components, adding functionality, or modifying behavior
- To explore user intent, requirements, and design before implementation

## Workflow
1.  **Explore project context**: Check files, docs, and recent commits.
2.  **Ask clarifying questions**: One at a time. Understand purpose, constraints, and success criteria.
3.  **Propose 2-3 approaches**: With trade-offs and your recommendation.
4.  **Present design sections**: Scaled to their complexity. Get user approval after each section (Architecture, components, data flow, error handling, testing).
5.  **Write design doc**: Save the validated design to `docs/plans/YYYY-MM-DD-<topic>-design.md` and commit.
6.  **Transition to implementation**: Proceed to creating an implementation plan.

<HARD-GATE>
Do NOT invoke any implementation skill, write any code, scaffold any project, or take any implementation action until you have presented a design and the user has approved it. This applies to EVERY project regardless of perceived simplicity.
</HARD-GATE>

## Instructions

**Asking Questions:**
- Prefer multiple-choice questions when possible.
- Only one question per message. Break topics into multiple questions if needed.
- YAGNI ruthlessly.

**Exploring approaches:**
- Propose 2-3 different approaches, lead with the recommended option.

**Presenting the design:**
- Scale sections to complexity. Get user approval after each section.
- Be flexible and revise based on feedback.

## Resources
- Adapted from the `superpowers` brainstorming skill.
