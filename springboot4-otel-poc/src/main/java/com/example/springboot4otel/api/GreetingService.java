package com.example.springboot4otel.api;

import java.time.Instant;
import java.util.List;
import java.util.concurrent.atomic.AtomicLong;
import org.springframework.stereotype.Service;

@Service
public class GreetingService {

    private final AtomicLong counter = new AtomicLong(0);

    public List<Greeting> list() {
        return List.of(
            new Greeting(counter.incrementAndGet(), "Olá, Spring Boot 4!", Instant.now()),
            new Greeting(counter.incrementAndGet(), "Observabilidade com OpenTelemetry", Instant.now())
        );
    }

    public Greeting create(String message) {
        return new Greeting(counter.incrementAndGet(), message, Instant.now());
    }
}
