package com.example.springboot4otel.api;

import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/greetings")
public class GreetingController {

    private final GreetingService greetingService;

    public GreetingController(GreetingService greetingService) {
        this.greetingService = greetingService;
    }

    @GetMapping
    public List<Greeting> list() {
        return greetingService.list();
    }

    @PostMapping
    public ResponseEntity<Greeting> create(@RequestBody GreetingPayload payload) {
        Greeting created = greetingService.create(payload.message());
        return ResponseEntity.ok(created);
    }

    @GetMapping("/{id}")
    public ResponseEntity<Greeting> byId(@PathVariable Long id) {
        // Como os greetings são gerados em memória, simplesmente recalculamos quando solicitado.
        return greetingService.list().stream()
            .filter(g -> g.id().equals(id))
            .findFirst()
            .map(ResponseEntity::ok)
            .orElseGet(() -> ResponseEntity.notFound().build());
    }

    public record GreetingPayload(String message) {
    }
}
