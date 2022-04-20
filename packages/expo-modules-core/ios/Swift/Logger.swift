// Copyright 2021-present 650 Industries. All rights reserved.

import Dispatch
import os.log

public let log = Logger(category: "expo")

public class Logger {
  #if DEBUG
  private var minLevel: LogType = .trace
  #else
  private var minLevel: LogType = .info
  #endif

  private let category: String

  private var handlers: [LogHandler] = []

  init(category: String = "main") {
    self.category = category

    if #available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *) {
      addHandler(withType: OSLogHandler.self)
    } else {
      addHandler(withType: PrintLogHandler.self)
    }
  }

  internal func addHandler<LogHandlerType: LogHandler>(withType: LogHandlerType.Type) {
    handlers.append(LogHandlerType(category: category))
  }

  // MARK: Public logging functions

  /**
   The most common type of logs, that helps tracing the code.
   It shouldn't contain any states of the variables.
   */
  public func trace(_ items: Any...) {
    log(type: .trace, items)
  }

  /**
   Used to log diagnostically helpful informations, including states of variables.
   */
  public func debug(_ items: Any...) {
    log(type: .debug, items)
  }

  /**
   For informations that should be logged under normal conditions such as successful initialization.
   */
  public func info(_ items: Any...) {
    log(type: .info, items)
  }

  /**
   Used to log an unwanted state that has not much impact on the process so it can be continued.
   */
  public func warn(_ items: Any...) {
    log(type: .warn, items)
  }

  /**
   Logs unwanted state that has impact on the currently running process, but the entire app can continue to run.
   */
  public func error(_ items: Any...) {
    log(type: .error, items)
  }

  /**
   Logs critical error due to which the entire app cannot continue to run.
   */
  public func fatal(_ items: Any...) {
    log(type: .fatal, items)
  }

  /**
   Logs the stack of symbols on the current thread.
   */
  public func stacktrace(file: String = #fileID, line: UInt = #line) {
    let queueName = OperationQueue.current?.underlyingQueue?.label ?? "<unknown>"

    // Get the call stack symbols without the first symbol as it points right here.
    let symbols = Thread.callStackSymbols.dropFirst()

    log(type: .stacktrace, "The stacktrace from '\(file):\(line)' on queue '\(queueName)':")

    symbols.forEach { symbol in
      let formattedSymbol = reformatStackSymbol(symbol)
      log(type: .stacktrace, "≫ \(formattedSymbol)")
    }
  }

  /**
   Allows the logger instance to be called as a function. The same as `logger.debug(...)`.
   */
  public func callAsFunction(_ items: Any...) {
    log(type: .debug, items)
  }

  // MARK: Timers

  /**
   Stores the timers created by `timeStart` function.
   */
  private var timers: [String: DispatchTime] = [:]

  /**
   Starts the timer to measure how much time the following operations take.
   */
  public func timeStart(_ id: String) {
    log(type: .timer, "Starting timer '\(id)'")
    timers[id] = DispatchTime.now()
  }

  /**
   Stops the timer and logs how much time elapsed since it started.
   */
  public func timeEnd(_ id: String) {
    guard let startTime = timers[id] else {
      log(type: .timer, "Timer '\(id)' has not been started!")
      return
    }
    let endTime = DispatchTime.now()
    let diff = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000
    log(type: .timer, "Timer '\(id)' has finished in: \(diff) seconds")
    timers.removeValue(forKey: id)
  }

  /**
   Measures how much time it takes to run given closure. Returns the same value as the closure returned.
   */
  public func time<ReturnType>(_ id: String, _ closure: () -> ReturnType) -> ReturnType {
    timeStart(id)
    let result = closure()
    timeEnd(id)
    return result
  }

  // MARK: Changing the category

  public func category(_ category: String) -> Logger {
    return Logger(category: category)
  }

  // MARK: Private logging functions

  private func log(type: LogType = .trace, _ items: [Any]) {
    guard type.rawValue >= minLevel.rawValue else {
      return
    }
    let message = items
      .map { String(describing: $0) }
      .joined(separator: " ")
      .split(whereSeparator: \.isNewline)
      .map { "\(type.prefix) \($0)" }
      .joined()

    handlers.forEach { handler in
      handler.log(type: type, message)
    }
  }

  private func log(type: LogType = .trace, _ items: Any...) {
    log(type: type, items)
  }
}

internal protocol LogHandler {
  init(category: String)

  func log(type: LogType, _ message: String)
}

@available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
private class OSLogHandler: LogHandler {
  private let osLogger: os.Logger

  required init(category: String) {
    osLogger = os.Logger(subsystem: "dev.expo.modules", category: category)
  }

  func log(type: LogType, _ message: String) {
    osLogger.log(level: type.toOSLogType(), "\(message)")
  }
}

private class PrintLogHandler: LogHandler {
  required init(category: String) {}

  func log(type: LogType, _ message: String) {
    print(message)
  }
}

internal enum LogType: Int {
  case trace = 0
  case stacktrace = 1
  case timer = 2
  case debug = 3
  case info = 4
  case warn = 5
  case error = 6
  case fatal = 7

  var prefix: String {
    switch self {
    case .trace:
      return "⚪️"
    case .stacktrace:
      return "🟣"
    case .timer:
      return "🟤"
    case .debug:
      return "🔵"
    case .info:
      return "🟢"
    case .warn:
      return "🟡"
    case .error:
      return "🟠"
    case .fatal:
      return "🔴"
    }
  }

  @available(macOS 11.0, iOS 14.0, watchOS 7.0, tvOS 14.0, *)
  func toOSLogType() -> OSLogType {
    switch self {
    case .trace, .stacktrace, .timer, .debug:
      return .debug
    case .info:
      return .info
    case .warn:
      return .default
    case .error:
      return .error
    case .fatal:
      return .fault
    }
  }
}

private func reformatStackSymbol(_ symbol: String) -> String {
  return symbol.replacingOccurrences(of: #"^\d+\s+"#, with: "", options: .regularExpression)
}
