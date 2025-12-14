package com.example.springboot4otel;

import com.example.springboot4otel.domain.Product;
import com.example.springboot4otel.repository.ProductRepository;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

@SpringBootApplication
public class Springboot4OtelPocApplication {

    public static void main(String[] args) {
        SpringApplication.run(Springboot4OtelPocApplication.class, args);
    }

    @Bean
    CommandLineRunner initDatabase(ProductRepository repository) {
        return args -> {
            repository.save(new Product("Laptop", 1200.00));
            repository.save(new Product("Mouse", 25.00));
            repository.save(new Product("Keyboard", 75.00));
        };
    }
}
