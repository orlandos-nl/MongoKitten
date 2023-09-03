---
name: Bug report
about: Create a report to help us improve
title: ''
labels: bug
assignees: Joannis
body:
  - type: markdown
    attributes:
      value: "## Welcome!"
  - type: markdown
    attributes:
      value: |
        Thanks for taking the time to fill out this bug! If you need real-time help, join us on Discord.
  - type: textarea
    id: "bug-description"
    attributes:
      label: 'Describe the Bug'
      description: 'A clear and concise description of what the bug is'
    validations:
      required: true
  - type: textarea
    id: "expected-behavior"
    attributes:
      label: 'Expected Behavior'
      description: 'A description of what you expect to happen'
  - type: input
    id: "operating-system"
    attributes:
      label: 'Operating System'
      description: "One or more OSes that you've experienced this bug on."
      placeholder: 'macOS Sonoma'
    validations:
      required: true
  - type: input
    id: "swift-version"
    attributes:
      label: 'Swift Version'
      description: "One or more Swift releases that you've experienced this bug on."
      placeholder: 'Swift 5.8'
    validations:
      required: true
  - type: input
    id: "mongokitten-version"
    attributes:
      label: 'MongoKitten Version'
      description: "One or more MongoKitten releases that you've experienced this bug on."
  - type: textarea
    id: "additional-context"
    attributes:
      label: 'Additional Context'
      description: 'Add any other context about the problem here.'
---
