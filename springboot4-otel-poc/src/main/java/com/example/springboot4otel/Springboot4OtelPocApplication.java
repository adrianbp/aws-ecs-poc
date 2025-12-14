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
        System.out.println("DEBUG: Pre-fix java.version=" + System.getProperty("java.version"));
        System.out.println("DEBUG: Pre-fix java.specification.version=" + System.getProperty("java.specification.version"));
        
        // Workaround for Spring Boot 4 Native Image check
        System.setProperty("java.version", "25");
        System.setProperty("java.specification.version", "25");
        
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
