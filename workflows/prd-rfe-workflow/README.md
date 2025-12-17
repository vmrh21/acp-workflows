# PRD & RFE Creation Workflow for Ambient Code Platform

A comprehensive workflow for creating Product Requirements Documents (PRDs) and systematically breaking them down into actionable Request for Enhancement (RFE) items. 

## Workflow

```mermaid
flowchart LR
    A[prd.discover] --> review_loop
    
    subgraph review_loop["PRD Review Loop"]
        B[prd.create] --> C[prd.review]
        C --> D[prd.revise]
        D --> B
    end
    
    subgraph rfe_loop["RFE Review Loop"]
        E[prd.breakdown] --> F[rfe.review]
        F --> G[rfe.revise]
        G --> E
    end
    
    review_loop --> rfe_loop
    rfe_loop --> H[rfe.submit]
```

## Workflow Steps & Collaborators

### 1. `prd.discover` - Product Discovery
**Purpose**: Understand the problem space, user needs, and market opportunity. Coordinate with adjacent products that may exist or are in development.

**Collaborating Agents**:
- **@parker-product_manager.md** - Market strategy, competitive analysis, opportunity quantification
- **@ryan-ux_researcher.md** - User insights from research studies, evidence-based requirements (CRITICAL: grounds requirements in available research from "All UXR Reports" folder)
- **@aria-ux_architect.md** (bullpen) - User journey mapping, ecosystem-level UX strategy

**Key Actions**:
- Define problem statement and business goals
- Collect source materials such as notes and links to related code repositories
- Research user pain points with data from existing studies
- Analyze competitive landscape and market opportunity
- Document assumptions and success metrics

---

### 2. `prd.create` - PRD Creation
**Purpose**: Create a comprehensive Product Requirements Document

**Collaborating Agents**:
- **@parker-product_manager.md** - Business requirements, value proposition, ROI justification
- **@ryan-ux_researcher.md** - Research-informed requirements with citations from studies
- **@terry-technical_writer.md** - Documentation quality, clarity, and structure
- **@casey-content_strategist.md** (bullpen) - Content architecture and standards

**Key Actions**:
- Write executive summary and product vision
- Document goals, success metrics, and KPIs
- Define user stories with research backing
- Specify functional and non-functional requirements

---

### 3. `prd.review` - PRD Review
**Purpose**: Review PRD for quality, completeness, and feasibility; determine if prototyping is needed

**Collaborating Agents**:
- **@steve-ux_designer.md** - UX assessment, determine if prototype needed for validation
- **@aria-ux_architect.md** (bullpen) - Holistic UX strategy validation, journey alignment
- **@olivia-product_owner.md** (bullpen) - Story readiness, acceptance criteria validation
- **@archie-architect.md** (bullpen) - Technical feasibility, architecture alignment

**Key Actions**:
- Validate requirements are clear and testable
- Assess if prototype is needed for user validation
- Check technical feasibility and architecture fit
- Ensure documentation meets quality standards

---

### 4. `prd.revise` - PRD Revision
**Purpose**: Revise PRD based on review feedback

**Collaborating Agents**:
- **@parker-product_manager.md** - Business value adjustments, strategic refinements
- **@terry-technical_writer.md** - Clarity improvements, documentation structure

**Key Actions**:
- Address review feedback and gaps
- Strengthen requirements with additional research
- Improve clarity and structure
- Validate all acceptance criteria are testable

---

### 5. `prd.breakdown` - RFE Breakdown
**Purpose**: Break down PRD into actionable Request for Enhancement items

**Recommended Agents**:
- **@olivia-product_owner.md** (bullpen) - Backlog management, story decomposition, acceptance criteria
- **@stella-staff_engineer.md** - Technical scoping, effort estimation, complexity assessment
- **@archie-architect.md** (bullpen) - System design, dependencies, architectural coordination
- **@neil-test_engineer.md** (bullpen) - Testability assessment, automation requirements, cross-component impact

**Key Actions**:
- Decompose PRD into implementable RFEs
- Define clear acceptance criteria for each RFE
- Identify technical dependencies and risks
- Size RFEs and assess testing requirements

---

### 6. `rfe.review` - RFE Review
**Purpose**: Review RFEs for technical feasibility, testability, and team capacity

**Collaborating Agents**:
- **@stella-staff_engineer.md** - Technical feasibility, implementation complexity, risk assessment
- **@archie-architect.md** (bullpen) - Architecture alignment, system-level implications
- **@neil-test_engineer.md** (bullpen) - Testing requirements, automation strategy, cross-team impact
- **@emma-engineering_manager.md** (bullpen) - Team capacity planning, delivery coordination
- **@olivia-product_owner.md** (bullpen) - Acceptance criteria validation, scope negotiation

**Key Actions**:
- Validate technical approach and feasibility
- Assess testability and automation requirements
- Check team capacity and delivery timeline
- Ensure architecture alignment

---

### 7. `rfe.revise` - RFE Revision
**Purpose**: Revise RFEs based on technical and capacity feedback

**Collaborating Agents**:
- **@olivia-product_owner.md** (bullpen) - Story refinement, scope adjustments
- **@stella-staff_engineer.md** - Technical design adjustments, complexity reduction
- **@neil-test_engineer.md** (bullpen) - Test requirements clarification, testability improvements

**Key Actions**:
- Address technical concerns and risks
- Refine acceptance criteria for clarity
- Adjust scope based on capacity constraints
- Enhance testability of requirements

---

### 8. `rfe.submit` - RFE Submission
**Purpose**: Submit approved RFEs for implementation planning and team assignment

**Collaborating Agents**:
- **@olivia-product_owner.md** (bullpen) - Backlog prioritization, sprint planning
- **@emma-engineering_manager.md** (bullpen) - Team assignment, capacity allocation, delivery coordination
- **@parker-product_manager.md** - Roadmap alignment, stakeholder communication

**Key Actions**:
- Prioritize RFEs in backlog
- Assign to appropriate teams
- Align with product roadmap
- Communicate to stakeholders

---

## Artifacts Generated

All workflow artifacts are organized in the `artifacts/` directory:

```
artifacts/
├── discovery.md                  # Product discovery document
├── requirements.md               # Detailed requirements
├── prd.md                        # Product Requirements Document
├── prd-checklist.md              # PRD quality checklist
├── rfes.md                       # RFE master list
├── rfe-tasks/                    # Individual RFE documents
│   ├── RFE-001-feature-name.md
│   ├── RFE-002-feature-name.md
│   └── ...
├── roadmap-visual.md             # Visual roadmap (optional)
└── review-report.md              # Quality review report
```

## Getting Started

### Quick Start

1. **Create an AgenticSession** in the Ambient Code Platform
2. **Select "PRD & RFE Creation"** from the workflows dropdown
3. **Start with `/prd.discover`** to begin product discovery
4. **Follow the phases** sequentially or jump to any phase based on your context

### Example Usage

**Scenario 1: New product idea**
```
User: "We want to add a user analytics dashboard to help users track their usage patterns"

Workflow: /prd.discover to understand the problem and opportunity
→ /prd.requirements to gather detailed requirements
→ /prd.create to generate comprehensive PRD
→ /rfe.breakdown to create implementable RFEs
→ /rfe.prioritize to plan implementation roadmap
→ /review to validate quality
```

**Scenario 2: You already have requirements**
```
User: "I have detailed requirements for a new reporting feature"

Workflow: Jump to /prd.create to generate PRD
→ /rfe.breakdown to create RFEs
→ /rfe.prioritize to plan roadmap
→ /review to validate
```

**Scenario 3: You have a PRD and need RFEs**
```
User: "I have a complete PRD for our mobile app redesign and need to break it into RFEs"

Workflow: Jump to /rfe.breakdown to decompose into RFEs
→ /rfe.prioritize to plan implementation
→ /review to validate coverage
```

### Prerequisites

- Clear understanding of the problem or product opportunity
- Access to user research, market data, or competitive analysis (helpful but not required)
- Stakeholder alignment on business goals and success metrics
- Understanding of technical constraints and dependencies (for RFE breakdown)

## Agent Orchestration

Agent collaboration is automatically triggered when you use the workflow commands—specialized agents are orchestrated as needed to ensure high-quality product documentation. Additionally, you can bring any individual agent into a conversation at any point by typing the '@' symbol and selecting an agent by name.


## Best Practices

### Discovery
- Focus on understanding the problem before jumping to solutions
- Validate assumptions with user research and data
- Document what you don't know
- Identify risks and constraints early

### Requirements
- Make every requirement testable and measurable
- Use clear, unambiguous language
- Define acceptance criteria upfront
- Document assumptions and dependencies
- Clearly define what's in scope and out of scope

### PRD Creation
- Write for your audience (executives, stakeholders, technical teams)
- Focus on WHAT and WHY, not HOW
- Use measurable success metrics
- Include visual aids (tables, diagrams) where helpful
- Keep technical implementation details out of the PRD

### RFE Breakdown
- Each RFE should be independently valuable and deliverable
- Size RFEs appropriately (not too large, not too small)
- Define clear acceptance criteria for every RFE
- Ensure traceability back to PRD requirements
- Identify and document dependencies clearly

### Prioritization
- Prioritize based on business value and user impact
- Consider dependencies and risks
- Each roadmap phase should deliver cohesive value
- Be transparent about trade-offs and what's deferred
- Align priorities with business goals

### Review
- Check traceability from PRD to RFEs
- Validate completeness and quality
- Look for gaps, contradictions, and ambiguities
- Ensure documentation is stakeholder-ready
- Address critical issues before implementation

## Customization

### For Your Organization

You can customize this workflow by:

1. **Customizing PRD template** in `/prd.create` to match your org's format
2. **Adding custom prioritization methods** in `/rfe.prioritize`
3. **Modifying RFE sizing criteria** to match your team's velocity
4. **Adding company-specific agents** for domain expertise
5. **Extending phases** with additional validation steps
6. **Customizing artifact paths** to match your document management system

### Industry-Specific Adjustments

Adjust the workflow for different industries:

- **SaaS**: Add subscription metrics and user onboarding considerations
- **Enterprise**: Include compliance, security, and governance requirements
- **Mobile Apps**: Add app store requirements and device compatibility
- **Healthcare**: Include HIPAA and regulatory compliance
- **Financial Services**: Add security, audit, and compliance sections

## Integration with ACP

This workflow integrates seamlessly with the Ambient Code Platform:

- **Workflow Selection**: Choose "PRD & RFE Creation" when creating AgenticSession
- **Artifact Management**: All outputs saved to `artifacts/` directory
- **Agent Invocation**: Automatically suggests agents based on phase and complexity
- **Progressive Disclosure**: Jump to any phase based on your context
- **Version Control**: All artifacts are plain markdown for easy versioning

## Contributing

Found issues with the workflow or have improvements?

- **Report issues**: [ambient-workflows issues](https://github.com/ambient-code/ambient-workflows/issues)
- **Suggest improvements**: Create a PR with your enhancements
- **Share learnings**: Document what worked well for your team

## License

This workflow is part of the Ambient Code Platform Workflows collection.

## Support

- **Documentation**: See [Ambient Code Platform docs](https://ambient-code.github.io/platform/)
- **Issues**: [File a bug](https://github.com/ambient-code/ambient-workflows/issues)
- **Questions**: Ask in the ACP community channels

---

**Happy Product Planning! 📋→🚀**
