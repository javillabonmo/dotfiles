# .NET Error Handling & Observability Guide

## Philosophy

Error handling and logging are not independent concerns.

They are different parts of the same diagnostic system.

An exception represents something that went wrong.

A log records what went wrong.

For that reason, they must always be designed together.

The primary goal of logging is **not** to describe how the application executes.

The primary goal is to make production failures diagnosable.

A useful log should answer questions such as:

- What failed?
- Where did it fail?
- Why did it fail?
- What operation was being executed?
- Which identifiers are involved?
- Can this issue be correlated with other logs?

If a log does not help answer those questions, it probably should not exist.

The objective is to maximize diagnostic value while minimizing log volume.

High signal.

Low noise.

The codebase should never rely on logs to understand normal application flow.

Logging is not tracing.

Logging is not debugging.

Logging is not telemetry.

Logging is a diagnostic mechanism for unexpected situations.

Unless explicitly requested otherwise, generated code should always favor:

- fewer logs
- richer logs
- structured logs
- contextual exceptions
- centralized error reporting

over verbose execution tracing.


# Goals

Generated code should:

- Preserve exception types.
- Preserve stack traces.
- Produce one error log per failure.
- Use structured logging exclusively.
- Attach useful diagnostic context.
- Avoid duplicate logs.
- Minimize unnecessary catch blocks.
- Produce logs compatible with centralized log aggregation.
- Produce code that is maintainable and observable.
- Generate logs with a high diagnostic value.
- Avoid introducing log noise.

# Logging Stack

Unless explicitly instructed otherwise, every ASP.NET Core project should assume the following logging stack.

## Logging

- Serilog
- Serilog.AspNetCore

## Centralized Log Storage

- Serilog.Sinks.Grafana.Loki

## Code Style

- StyleCop.Analyzers

These packages are considered part of the project's standard infrastructure.

Generated code should assume they are already configured.

Do not generate alternative logging abstractions unless explicitly requested.

Prefer using:

```csharp
ILogger<T>
```

through dependency injection.

Do not instantiate loggers manually.

Do not use static logger instances inside business code.

The application's startup is responsible for configuring Serilog.

Business code is responsible only for producing structured diagnostic events.

# Logging Philosophy

Logs exist to explain failures.

Logs do not exist to narrate execution.

Avoid logs describing successful execution.

Bad examples:

- Request started.
- Request finished.
- Repository executed.
- Customer loaded.
- Product updated.
- Entering method.
- Leaving method.
- Validation succeeded.
- Authentication completed.
- Database connection opened.
- Query executed successfully.

These events create noise while providing little diagnostic value.

Instead, logs should describe situations requiring investigation.

Good examples:

- External API unavailable.
- Retry policy exhausted.
- Invalid application state.
- Database timeout.
- Message processing failed.
- Unexpected null value.
- Configuration inconsistency.
- Cache unavailable.
- Data corruption detected.
- Background job failed.
- Circuit breaker opened.
- Retry limit exceeded.

A production log should represent one of the following:

- An unexpected condition.
- A recoverable failure.
- An unrecoverable failure.
- A security event.
- A business anomaly.
- An infrastructure problem.
- An operational issue requiring investigation.

Everything else generally does not belong in the log stream.

Information-level logs should be extremely uncommon.

Generated code should never introduce LogInformation() merely to describe successful execution.

If a developer wants execution tracing, that should be implemented using distributed tracing, profiling, or debugging tools—not application logs.

# Exception Philosophy

Exceptions are not failures of the programming language.

They are explicit representations of operations that could not complete successfully.

An exception should either:

- propagate naturally,
- be enriched with diagnostic information,
- be translated into a meaningful domain exception,
- be handled because the application can recover.

No other reasons justify catching an exception.

A catch block should always have a clearly defined responsibility.

If a catch block exists only to log and immediately rethrow the exception, it should be removed.

Bad:

```csharp
catch (Exception ex)
{
    _logger.LogError(ex, "Order processing failed.");
    throw;
}
```

Good:

```csharp
catch (Exception ex)
{
    ex.Data["OrderId"] = order.Id;
    throw;
}
```

Logging belongs to the application's boundary.

Lower layers should focus on preserving context rather than reporting failures.

The application boundary is responsible for transforming exceptions into diagnostic events.

---

## Preserve the Original Exception

Unless there is a business reason to introduce a different exception type, preserve the original exception.

Avoid:

```csharp
throw new Exception(
    "Database operation failed.",
    ex);
```

Prefer:

```csharp
ex.Data["CustomerId"] = customerId;
throw;
```

The original exception already contains:

- the correct stack trace,
- the original message,
- the original type,
- vendor-specific diagnostic information.

Replacing it usually removes valuable debugging information.

---

## Preserve Stack Traces

Always rethrow using:

```csharp
throw;
```

Never use:

```csharp
throw ex;
```

Using `throw ex;` resets the stack trace and makes diagnosing production failures significantly harder.

---

## Catch Only When Necessary

Do not catch exceptions defensively.

Allow exceptions to propagate naturally.

A catch block should exist only when one or more of the following applies:

- Additional diagnostic context is available.
- Cleanup must occur.
- Recovery is possible.
- Retry logic is required.
- The exception must be translated into a business-specific exception.
- The exception reaches the application's logging boundary.

Otherwise, remove the catch block entirely.

---

## Avoid Defensive Catch Blocks

Bad:

```csharp
try
{
    return repository.Get(id);
}
catch
{
    throw;
}
```

Bad:

```csharp
try
{
    Save();
}
catch (Exception)
{
    throw;
}
```

These blocks provide no value.

They should not exist.

---

## Domain Exceptions

Wrapping exceptions is acceptable only when introducing additional business meaning.

Good:

```csharp
catch (SqlException ex)
{
    throw new CustomerRepositoryException(
        customerId,
        ex);
}
```

Good:

```csharp
catch (HttpRequestException ex)
{
    throw new ExternalInventoryUnavailableException(
        ex);
}
```

Bad:

```csharp
catch (Exception ex)
{
    throw new Exception(
        "Something failed.",
        ex);
}
```

Changing only the message adds no semantic value.

---

## Prefer Context Over Wrapping

Whenever possible, enrich the exception instead of replacing it.

Good:

```csharp
catch (Exception ex)
{
    ex.Data["OrderId"] = order.Id;
    ex.Data["CustomerId"] = customer.Id;
    ex.Data["Operation"] = "Checkout";

    throw;
}
```

This preserves every diagnostic property while adding application-specific metadata.

---

## Exception Flow

Exceptions should naturally travel upward through the application's layers.

```
Infrastructure
        │
Repository
        │
Application
        │
API
        │
Exception Middleware
        │
Structured Log
        │
Grafana Loki
```

Every layer may enrich the exception.

Only one layer should report it.

---

## One Exception, One Log

A single failure should produce exactly one error log.

Multiple logs describing the same exception reduce signal quality and complicate diagnostics.

Good:

Repository

```csharp
catch (SqlException ex)
{
    ex.Data["CustomerId"] = customerId;
    throw;
}
```

Middleware

```csharp
logger.LogError(
    ex,
    "Unhandled exception.");
```

Bad:

Repository

```csharp
_logger.LogError(ex, "Database failed.");
throw;
```

Application

```csharp
_logger.LogError(ex, "Processing failed.");
throw;
```

Controller

```csharp
_logger.LogError(ex, "Request failed.");
throw;
```

Middleware

```csharp
logger.LogError(ex, "Unhandled exception.");
```

The same failure should never generate four independent error logs.

---

## Exception Handling Decision Tree

When catching an exception, ask the following questions:

1. Can the application recover?

If yes:

- Recover.
- Do not rethrow.

2. Is additional context available?

If yes:

- Add data to `Exception.Data`.
- Rethrow.

3. Is this the application's boundary?

If yes:

- Produce the structured log.
- Generate the appropriate HTTP response.

4. Does the exception require a different business meaning?

If yes:

- Wrap it in a domain-specific exception.

If every answer is "no", remove the catch block.


# Exception.Data

`Exception.Data` is the preferred mechanism for attaching diagnostic context to an exception.

It allows every layer of the application to contribute information without:

- modifying the exception type,
- creating wrapper exceptions,
- producing duplicate logs,
- losing the original stack trace.

The goal is that when the exception finally reaches the application's logging boundary, it already contains every relevant piece of diagnostic information.

---

## Philosophy

Context should be added where it is first known.

Do not wait until the middleware to reconstruct information that was available several layers earlier.

For example:

- Repository knows the table.
- Infrastructure knows the external provider.
- Application knows the business operation.
- Controller knows the request.
- Middleware knows the HTTP context.

Each layer should enrich the exception only with information it uniquely owns.

---

## Preferred Metadata

Good candidates include:

- CorrelationId
- TraceId
- RequestId
- UserId
- TenantId
- CustomerId
- OrderId
- ProductId
- InvoiceId
- EntityId
- EntityName
- Aggregate
- Operation
- Repository
- Service
- Database
- Table
- Collection
- Query
- FilePath
- Endpoint
- RequestPath
- HttpMethod
- ExternalProvider
- ExternalEndpoint
- MessageId
- QueueName
- RetryAttempt

These values should be lightweight.

Prefer identifiers over objects.

---

## Avoid Large Objects

Never store:

- HttpContext
- DbContext
- IServiceProvider
- Stream
- FileStream
- HttpRequest
- HttpResponse
- Domain entities
- DTOs
- Entire collections

Bad:

```csharp
ex.Data["Customer"] = customer;
```

Good:

```csharp
ex.Data["CustomerId"] = customer.Id;
```

---

## Sensitive Information

Never store confidential information.

Forbidden examples:

- Password
- JWT
- RefreshToken
- Bearer Token
- API Key
- Connection String
- Credit Card
- CVV
- Cookie
- Authentication Header
- Encryption Keys
- Secrets

Logs are frequently exported outside the application.

Assume every value stored in `Exception.Data` may eventually become visible inside Grafana Loki.

---

## Consistent Keys

Use consistent property names across the solution.

Prefer:

```text
OrderId
CustomerId
CorrelationId
RequestId
UserId
Endpoint
Operation
```

Avoid:

```text
order_id
customer
Order
CurrentCustomer
ReqId
```

Consistency significantly improves querying inside Loki.

---

## Layer Responsibilities

Repository

```csharp
catch (SqlException ex)
{
    ex.Data["Table"] = "Orders";
    ex.Data["OrderId"] = orderId;
    throw;
}
```

External Service

```csharp
catch (HttpRequestException ex)
{
    ex.Data["Provider"] = "Stripe";
    ex.Data["Endpoint"] = "/payments";
    throw;
}
```

Application Service

```csharp
catch (Exception ex)
{
    ex.Data["Operation"] = "Checkout";
    throw;
}
```

Each layer contributes information.

No layer logs.

---

## Do Not Overwrite Existing Values

When adding metadata, preserve existing context whenever possible.

Good:

```csharp
if (!ex.Data.Contains("OrderId"))
{
    ex.Data["OrderId"] = order.Id;
}
```

Avoid replacing values coming from lower layers unless the existing value is incorrect.

---

## Extension Method

To reduce repetitive code, prefer using an extension method.

```csharp
public static class ExceptionExtensions
{
    public static T AddData<T>(
        this T exception,
        string key,
        object? value)
        where T : Exception
    {
        if (!exception.Data.Contains(key))
        {
            exception.Data[key] = value;
        }

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
        .AddData("CustomerId", customer.Id)
        .AddData("Operation", "Checkout");
}
```

This keeps catch blocks concise while preserving consistency.

---

## Exception.Data and Serilog

At the application's boundary, the logging infrastructure should enrich structured logs with every value contained in `Exception.Data`.

Generated code should assume this enrichment already exists.

Business code should not manually copy `Exception.Data` into log statements.

The middleware is responsible for transforming exception metadata into structured log properties.

---

## Exception.Data Checklist

Before rethrowing an exception, ask:

- Is there diagnostic information available here?
- Will this information help identify the failure?
- Is the value lightweight?
- Is the value non-sensitive?
- Is the key consistent with the rest of the application?

If every answer is yes, add it to `Exception.Data`.