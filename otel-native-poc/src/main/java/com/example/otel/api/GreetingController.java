package com.example.otel.api;

import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/greetings")
public class GreetingController {

    private final GreetingRepository repository;

    public GreetingController(GreetingRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public List<Greeting> list() {
        return repository.findAll();
    }

    @GetMapping("/{id}")
    public ResponseEntity<Greeting> byId(@PathVariable Long id) {
        return repository.findById(id)
            .map(ResponseEntity::ok)
            .orElseGet(() -> ResponseEntity.notFound().build());
    }
}
