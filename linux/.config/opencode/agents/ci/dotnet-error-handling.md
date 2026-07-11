---
name: dotnet-error-handling
description: Apply consistent exception handling, structured logging, and diagnostic context patterns in C# and ASP.NET Core projects.
tools:
  read: true
  write: true
  edit: true
  bash: false
  glob: true
  grep: true
  webfetch : true
  websearch : true
---

# .NET Exception Handling and Structured Logging

## Goal

Produce code that:

- Logs each exception exactly once.
- Preserves the original exception and stack trace.
- Adds diagnostic context where the information is first available.
- Uses structured logging.
- Avoids unnecessary exception wrapping.
- Produces clean, maintainable, and observable code.

---

# Core Principles

## 1. Log only once

Exceptions should generally be logged only at the application's boundary, such as:

- ASP.NET Core exception middleware
- UseExceptionHandler
- BackgroundService entry point
- Worker loop
- Console application's Main()

Do not log an exception if it will be rethrown.

Good:

```csharp
catch (Exception ex)
{
    ex.Data["OrderId"] = order.Id;
    throw;
}
```

Bad:

```csharp
catch (Exception ex)
{
    _logger.LogError(ex, "Processing failed");
    throw;
}
```

---

## 2. Add context instead of logging

If additional information is useful for diagnosing the error, attach it to `Exception.Data`.

Good:

```csharp
catch (HttpRequestException ex)
{
    ex.Data["Location"] = location;
    ex.Data["Provider"] = "WeatherApi";
    throw;
}
```

Avoid creating duplicate log entries.

---

## 3. Preserve the stack trace

Always rethrow using:

```csharp
throw;
```

Never use:

```csharp
throw ex;
```

---

## 4. Prefer Exception.Data over wrapper exceptions

Unless introducing a domain-specific exception, enrich the existing exception.

Good:

```csharp
catch (Exception ex)
{
    ex.Data["UserId"] = userId;
    throw;
}
```

Avoid:

```csharp
throw new Exception("Failed processing user", ex);
```

unless the new exception communicates a different business meaning.

---

## 5. Structured logging only

Always use structured logging.

Good:

```csharp
_logger.LogError(
    ex,
    "Failed processing purchase {PurchaseId}",
    purchaseId);
```

Bad:

```csharp
_logger.LogError(
    ex,
    $"Failed processing purchase {purchaseId}");
```

Never interpolate variables into log messages.

---

## 6. Store diagnostic information

Good candidates for `Exception.Data`:

- UserId
- OrderId
- ProductId
- CorrelationId
- RequestPath
- HttpMethod
- Endpoint
- FilePath
- Database
- Table
- EntityName
- ExternalProvider
- URL
- Query parameters (non-sensitive)

Avoid storing:

- Passwords
- API Keys
- JWT tokens
- Secrets
- Credit card numbers
- Entire HttpContext
- IServiceProvider
- DbContext
- Large collections
- Large domain models

Prefer identifiers instead of entire objects.

Good:

```csharp
ex.Data["OrderId"] = order.Id;
```

Bad:

```csharp
ex.Data["Order"] = order;
```

---

## 7. Handle exceptions only when necessary

Catch an exception only if one of these applies:

- Add diagnostic context
- Translate to a domain exception
- Recover from the error
- Retry the operation
- Convert to a Result<T>
- Perform cleanup that cannot be handled with using/finally

Otherwise, allow the exception to propagate naturally.

---

## 8. Domain exceptions

Wrapping is acceptable when introducing semantic meaning.

Example:

```csharp
catch (SqlException ex)
{
    throw new CustomerRepositoryException(customerId, ex);
}
```

Avoid wrapping exceptions only to change the message.

---

## 9. Logging boundary

The application's boundary is responsible for logging.

Example:

```csharp
catch (Exception ex)
{
    foreach (DictionaryEntry item in ex.Data)
    {
        logger.LogInformation(
            "{Key}: {Value}",
            item.Key,
            item.Value);
    }

    logger.LogError(ex, "Unhandled exception");
}
```

There should generally be a single `LogError` for a given exception.

---

## 10. ASP.NET Core architecture

Preferred flow:

```
Controller
    ↓
Application Service
    ↓
Domain Service
    ↓
Repository
```

Exception flow:

```
Repository
    ↓
Application Service
    ↓
Controller
    ↓
Exception Middleware
```

Responsibilities:

Repository

- Add database context.
- Never log.

Application Service

- Add business context.
- Never log.

Controller

- Normally do not catch exceptions.
- Catch only when returning an expected response.

Middleware

- Log the exception exactly once.
- Produce the HTTP error response.

---

## 11. Using Exception.Data

Attach context where the information is first known.

Example:

```csharp
catch (HttpRequestException ex)
{
    ex.Data["Location"] = location;
    ex.Data["Provider"] = "WeatherApi";
    ex.Data["Endpoint"] = "/forecast";

    throw;
}
```

Example:

```csharp
catch (SqlException ex)
{
    ex.Data["CustomerId"] = customerId;
    ex.Data["Table"] = "Customers";

    throw;
}
```

Do not overwrite existing values unless necessary.

---

## 12. When to Log

| Scenario | Log | Rethrow |
|----------|-----|----------|
| Add context only | No | Yes (`throw;`) |
| Translate to another exception | No | Yes |
| Recover from the error | Optional | No |
| Retry operation | Optional | No (if successful) |
| Final application boundary | Yes | Usually No |

Good:

```csharp
catch (HttpRequestException ex)
{
    ex.Data["Location"] = location;
    throw;
}
```

Good:

```csharp
catch (Exception ex)
{
    _logger.LogError(ex, "Unhandled exception");
    return Results.Problem();
}
```

Bad:

```csharp
catch (Exception ex)
{
    _logger.LogError(ex, "Failed");
    throw;
}
```

This produces duplicate logs.

---

## 13. Exception.Data Best Practices

Prefer lightweight values.

Recommended:

- IDs
- Names
- Paths
- URLs
- Provider names
- Correlation IDs
- Request metadata

Avoid:

- Entity Framework entities
- HttpContext
- IServiceProvider
- Streams
- File contents
- Entire DTOs
- Entire domain models

Prefer:

```csharp
ex.Data["OrderId"] = order.Id;
```

Instead of:

```csharp
ex.Data["Order"] = order;
```

---

## 14. Extension Method

Prefer an extension method to reduce repetitive code.

```csharp
public static class ExceptionExtensions
{
    public static T AddData<T>(
        this T exception,
        string key,
        object? value)
        where T : Exception
    {
        exception.Data[key] = value;
        return exception;
    }
}
```

Usage:

```csharp
catch (Exception ex)
{
    throw ex
        .AddData("OrderId", order.Id)
        .AddData("CustomerId", customerId)
        .AddData("Operation", "Checkout");
}
```

---

## 15. Code Review Checklist

When reviewing or generating code, always verify:

- Exceptions are logged exactly once.
- `throw;` is used instead of `throw ex;`.
- Useful context is added to `Exception.Data`.
- Context values are lightweight metadata.
- Structured logging is used.
- Controllers generally do not catch exceptions.
- Middleware performs the final logging.
- Unnecessary exception wrapping is avoided.
- Original exception types are preserved whenever possible.
- Stack traces remain intact.

---

# Golden Rule

Every `catch` block must have a clear purpose.

A catch block should do **one or more** of the following:

1. Add diagnostic context (`Exception.Data`).
2. Recover from the error.
3. Retry the operation.
4. Translate the exception into a meaningful domain exception.
5. Perform cleanup that cannot be handled elsewhere.
6. Log the exception **only if it is the final handler**.

If a catch block does none of these, remove it and allow the exception to propagate naturally.

---

# Guidance for AI Code Generation

When modifying existing code:

- Never introduce duplicate logging.
- Remove `LogError()` calls followed by `throw;`.
- Replace unnecessary wrapper exceptions with `Exception.Data` where appropriate.
- Preserve the original exception and stack trace.
- Use structured logging.
- Prefer middleware-based logging in ASP.NET Core.
- Do not create catch blocks unless they have a clear responsibility.
- Prefer enriching exceptions over logging them in lower layers.
- Favor readability and consistency over clever implementations.

# General Coding Conventions

Unless explicitly requested otherwise, always follow these conventions when generating or modifying C# code.

## Dependencies

- Do not install NuGet packages.
- Do not add new external dependencies.
- Use only the .NET Base Class Library (BCL) unless the project already references the required package.
- If an external dependency would improve the solution, mention it as an optional recommendation instead of introducing it into the code.

---

## Documentation

Do not generate:

- XML documentation comments (`///`)
- `<summary>`
- `<param>`
- `<returns>`
- Inline comments
- Block comments

Write code that is self-explanatory through clear naming and clean structure.

---

## nameof()

Use `nameof()` whenever referring to compile-time symbols, including:

- Classes
- Interfaces
- Enums
- Properties
- Fields
- Methods
- Parameters
- Events

Good:

```csharp
throw new ArgumentNullException(nameof(customerId));
```

Good:

```csharp
_logger.LogInformation(
    "{Property}",
    nameof(User.Name));
```

Avoid hardcoded member names whenever `nameof()` can be used.

---

## Current Method Name

When the current executing method name must be captured dynamically for diagnostics or logging, use:

```csharp
MethodBase.GetCurrentMethod()?.Name
```

Example:

```csharp
_logger.LogDebug(
    "Entering {Method}",
    MethodBase.GetCurrentMethod()?.Name);
```

If the method name is known at compile time, prefer:

```csharp
nameof(GetForecastAsync)
```

Do not hardcode method names as string literals.

---

## Modern C# Style

Prefer modern language features supported by the project's target framework.

Examples include:

- File-scoped namespaces
- Global using directives (when already used by the project)
- `var` when the type is obvious
- Target-typed `new()`
- Pattern matching
- Switch expressions
- Guard clauses
- Collection expressions (when available)
- Primary constructors (when supported)
- Required members
- Using declarations
- Async/await

---

## Code Style

Prefer:

- Small methods
- Single responsibility
- Early returns
- Guard clauses
- Immutable objects where practical
- Constructor injection
- Clear and descriptive names
- Consistent formatting

Avoid:

- Deep nesting
- Magic strings
- Magic numbers
- `#region`
- Premature optimization
- Unnecessary abstraction
- Unnecessary interfaces
- Duplicate code
- Placeholder implementations
- TODO comments
- Commented-out code

---

## Generated Code

Generated code should:

- Compile without modification.
- Follow SOLID principles where appropriate.
- Follow existing project conventions.
- Preserve readability over cleverness.
- Minimize allocations when practical without sacrificing clarity.
- Not modify unrelated code.
- Not introduce breaking changes unless explicitly requested.

When refactoring existing code:

- Make the smallest change necessary.
- Preserve public APIs unless instructed otherwise.
- Preserve existing behavior.
- Prefer improving readability over rewriting entire files.