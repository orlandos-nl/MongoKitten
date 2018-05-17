# OpenKitten Philosophy

## API Design

- APIs must be immediately obvious
- APIs must have a strongly limited complexity, delegating as much responsibility as reasonably possible
- APIs must be predictable: retreiving a value that was stored as an Int, should return an Int
- Follow the [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Easy to understand and use for beginners (high-level APIs and sensible default parameter values), but powerful for power users (low-level APIs)
- Because of our server-side focus, throw an error instead of using `fatalError` when possible, unless the cause is an obvious programming error

## API Documentation

- Functions and types must be documented using a documentation comment, but the documentation must be meaningful. `- parameter name: The name` is an example of unmeaningful documentation. In this case, it would be better to omit the description entirely.
- Documentation should link to reference materials or other documentation where applicable. For example, the offical MongoDB docs for a specific command.

## Performance

- When possible, pure Swift solutions have a strong preference over resorting to a C library, even if this means implementing an entirely new library
- Performance and readable code are not mutually exclusive. However, when a choice must be made, code clarity takes precedence
- Low level APIs have a strong need for performance
- Be lazy whenever possible, even if it comes at the cost of increased CPU usage: this significantly reduces the memory footprint for users with large datasets

`collection.find("name" == "henk").limit(10).skip(4)`