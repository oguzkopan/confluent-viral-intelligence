package logger

import (
	"os"
	"strings"
	"time"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

var (
	// Logger is the global zerolog logger instance
	Logger zerolog.Logger
	// currentLevel stores the current log level
	currentLevel zerolog.Level
)

// Init initializes the logger with the specified log level from environment
func Init() {
	// Get log level from environment variable (default: info)
	logLevelStr := strings.ToLower(os.Getenv("LOG_LEVEL"))
	if logLevelStr == "" {
		logLevelStr = "info"
	}

	// Parse log level
	var level zerolog.Level
	switch logLevelStr {
	case "debug":
		level = zerolog.DebugLevel
	case "info":
		level = zerolog.InfoLevel
	case "warn", "warning":
		level = zerolog.WarnLevel
	case "error":
		level = zerolog.ErrorLevel
	default:
		level = zerolog.InfoLevel
	}

	currentLevel = level

	// Configure zerolog
	zerolog.TimeFieldFormat = time.RFC3339
	Logger = zerolog.New(os.Stdout).
		Level(level).
		With().
		Timestamp().
		Logger()

	// Set global logger
	log.Logger = Logger

	Logger.Info().
		Str("level", level.String()).
		Msg("Logger initialized")
}

// Debug logs a debug message
func Debug(msg string) {
	if currentLevel <= zerolog.DebugLevel {
		Logger.Debug().Msg(msg)
	}
}

// Debugf logs a formatted debug message
func Debugf(format string, args ...interface{}) {
	if currentLevel <= zerolog.DebugLevel {
		Logger.Debug().Msgf(format, args...)
	}
}

// Info logs an info message
func Info(msg string) {
	if currentLevel <= zerolog.InfoLevel {
		Logger.Info().Msg(msg)
	}
}

// Infof logs a formatted info message
func Infof(format string, args ...interface{}) {
	if currentLevel <= zerolog.InfoLevel {
		Logger.Info().Msgf(format, args...)
	}
}

// Warn logs a warning message
func Warn(msg string) {
	if currentLevel <= zerolog.WarnLevel {
		Logger.Warn().Msg(msg)
	}
}

// Warnf logs a formatted warning message
func Warnf(format string, args ...interface{}) {
	if currentLevel <= zerolog.WarnLevel {
		Logger.Warn().Msgf(format, args...)
	}
}

// Error logs an error message
func Error(msg string) {
	Logger.Error().Msg(msg)
}

// Errorf logs a formatted error message
func Errorf(format string, args ...interface{}) {
	Logger.Error().Msgf(format, args...)
}

// Fatal logs a fatal message and exits
func Fatal(msg string) {
	Logger.Fatal().Msg(msg)
}

// Fatalf logs a formatted fatal message and exits
func Fatalf(format string, args ...interface{}) {
	Logger.Fatal().Msgf(format, args...)
}
