# Testing Best Practices

Guidance for writing clear, maintainable tests that serve as product documentation.

## Core Principles

### Delete tests that will not catch bugs

Only add tests that are practically likely to catch real bugs. Do not add excessive unit tests for the sake of 100% coverage.

### Readability over Comprehensiveness

Practical test readability is more important than exhaustively spelling out every behavior. Rely on implication to maximize economy of language.

A 10-line test protecting 99% of the business value is better than a 50-line test spelling out 99.9% of the behavior.

### Test Contravariance

Write tests to reflect concrete user/business requirements. Keep them concrete even as the code becomes abstract. Do not mirror test-code 1:1 if it interferes with communicating the business/product intention.

### Tests are Product Documentation

Structure tests to tell a story. Write for a Product Manager with no context about the implementation. Tests should clearly document use cases.

### Test folder structure is Product Documentation

Organize test files like the Table of Contents in a product manual. The file tree should communicate the product from a bird's eye view.

### DAMP over DRY

Prefer **DAMP** (Descriptive And Meaningful Phrases) over **DRY**:

- Prioritize readability over deduplication
- Extract helpers for clarity, not merely to reduce duplication

### Do not overengineer beyond Tests

Every piece of production code must be justified by a test demonstrating why it exists. Production code lacking test coverage must either:

- Be covered with tests, OR
- Be labelled with coverage-ignoring comments explaining why it's not worth testing, OR
- Be deleted — no test and no ignore comments implies _"This is intentionally unsupported to reduce complexity"_

The goal is clear communication about which use cases are supported/tested, not 100% test coverage for its own sake.

## Best Practices

### Name tests to communicate their value

Name tests to highlight:

- The use case (or family of use cases) being protected
- What differentiates this test case from others

### Use realistic test data

Prefer literal values that can be cross-referenced against real production data, over generic names like `foo`, so tests can be justified by looking at real examples.

### Focus Setup

Setup only the minimum data that the test case needs. Avoid mentioning or setting up data unrelated to the test name.

### Focus Assertions

Assert only what the test name describes. Avoid asserting the same behavior across multiple tests.

#### Minimize Test-Case Redundancy

When behavior X is tested in `TestFoo.test_X`, avoid re-asserting X in `TestFoo.test_Y`. Extract the specific item under test rather than asserting on entire response structures.

#### Minimize Test-Layer Redundancy

When `TestFooIntegration` covers cases `x, y, z`, avoid duplicating coverage in `TestFooUnit`. Prefer integration tests over unit tests when both are equally readable and fast.

## Anti-Patterns

### Redundant Comments

ALWAYS remove comments that restate the code.

### Skipping Tests

NEVER skip a test that fails. If a test cannot be written, that is a critical blocker.

### Overly Comprehensive Assertions

Only assert details relevant to the test name.

### Redundant Assertions Across Tests

Do not assert what has already been asserted by another test. Only assert properties that differentiate the test.
