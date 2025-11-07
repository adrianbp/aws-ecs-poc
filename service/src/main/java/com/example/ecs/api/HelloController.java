package com.example.ecs.api;

import java.time.Instant;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping({"/api","/dynatrace/api","/native/api"})
public class HelloController {

    @Value("${spring.application.name}")
    private String applicationName;
    private final GreetingRepository greetingRepository;

    public HelloController(GreetingRepository greetingRepository) {
        this.greetingRepository = greetingRepository;
    }

    @GetMapping("/info")
    public ResponseEntity<Map<String, Object>> info() {
        return ResponseEntity.ok(
            Map.of(
                "app", applicationName,
                "timestamp", Instant.now().toString(),
                "message", "ECS JVM tuning POC",
                "greetings", greetingRepository.findAll()
            )
        );
    }
}
