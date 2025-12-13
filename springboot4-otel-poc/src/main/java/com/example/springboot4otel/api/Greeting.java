package com.example.springboot4otel.api;

import java.time.Instant;

public record Greeting(Long id, String message, Instant createdAt) {
}
